package org.keyvox.platformlab.capture;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import java.io.File;
import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

/** Platform microphone ownership ends at an ordinary PCM WAV file. */
final class AudioCapture {
    interface Listener {
        void recording();
        void finished(File file, Exception failure);
    }

    private static final int SAMPLE_RATE = 16000;
    private final AtomicBoolean active = new AtomicBoolean();
    private final AtomicBoolean stopRequested = new AtomicBoolean();

    boolean isActive() { return active.get(); }
    synchronized void stop() { stopRequested.set(true); }

    void start(File directory, Listener listener) {
        if (!active.compareAndSet(false, true)) return;
        stopRequested.set(false);
        new Thread(new Runnable() {
            @Override public void run() { capture(directory, listener); }
        }, "KeyVoxAudioCapture").start();
    }

    private void capture(File directory, Listener listener) {
        AudioRecord recorder = null;
        File completed = null;
        Exception failure = null;
        try {
            if (directory == null || (!directory.isDirectory() && !directory.mkdirs())) {
                throw new IOException("Capture directory unavailable");
            }
            int minimum = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                                                       AudioFormat.ENCODING_PCM_16BIT);
            if (minimum <= 0) throw new IOException("Unsupported capture format: " + minimum);
            recorder = new AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minimum * 2);
            if (recorder.getState() != AudioRecord.STATE_INITIALIZED) {
                throw new IOException("AudioRecord initialization failed");
            }
            String identifier = UUID.randomUUID().toString();
            File partial = new File(directory, identifier + ".partial");
            File output = new File(directory, identifier + ".wav");
            if (!partial.createNewFile()) throw new IOException("Capture file already exists");
            completed = partial;
            try (WaveWriter writer = new WaveWriter(partial, SAMPLE_RATE)) {
                synchronized (this) {
                    if (stopRequested.get()) throw new IOException("Capture stopped before microphone start");
                    recorder.startRecording();
                }
                if (recorder.getRecordingState() != AudioRecord.RECORDSTATE_RECORDING) {
                    throw new IOException("Microphone did not start");
                }
                listener.recording();
                short[] buffer = new short[minimum / Short.BYTES];
                while (!stopRequested.get()) {
                    int count = recorder.read(buffer, 0, buffer.length, AudioRecord.READ_BLOCKING);
                    if (count <= 0) throw new IOException("AudioRecord read failed: " + count);
                    writer.write(buffer, count);
                }
            }
            if (!partial.renameTo(output)) throw new IOException("Cannot finalize capture");
            completed = output;
        } catch (Exception error) {
            failure = error;
        } finally {
            if (recorder != null) {
                try {
                    if (recorder.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) recorder.stop();
                } catch (RuntimeException error) {
                    if (failure == null) failure = error;
                }
                try {
                    recorder.release();
                } catch (RuntimeException error) {
                    if (failure == null) failure = error;
                }
            }
            active.set(false);
            listener.finished(completed, failure);
        }
    }
}
