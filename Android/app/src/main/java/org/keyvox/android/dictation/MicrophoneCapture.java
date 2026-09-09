package org.keyvox.android.dictation;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.function.Consumer;

/** Owns one microphone stream and writes the engine's mono Float32 PCM input. */
final class MicrophoneCapture {
    private static final int SAMPLE_RATE = 16000;
    // Matches the existing iOS SessionPolicy maximum utterance duration.
    private static final long MAX_FRAMES = SAMPLE_RATE * 15L * 60L;
    private volatile boolean stopped;
    void stop() { stopped = true; }

    void record(File file, Runnable started, Consumer<Float> meterUpdate) throws IOException {
        int minimum = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
        if (minimum <= 0) throw new IOException("Unsupported microphone format");
        AudioRecord recorder;
        try {
            recorder = new AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, Math.max(minimum, 8192));
        } catch (SecurityException error) { throw new IOException("Microphone permission unavailable", error); }
        try {
            if (recorder.getState() != AudioRecord.STATE_INITIALIZED) throw new IOException("Microphone initialization failed");
            if (stopped) throw new IOException("Capture cancelled before start");
            recorder.startRecording();
            if (recorder.getRecordingState() != AudioRecord.RECORDSTATE_RECORDING) throw new IOException("Microphone start failed");
            started.run();
            short[] samples = new short[2048];
            MicrophoneLevelMeter meter = new MicrophoneLevelMeter();
            ByteBuffer floats = ByteBuffer.allocate(samples.length * Float.BYTES).order(ByteOrder.LITTLE_ENDIAN);
            long frames = 0;
            try (BufferedOutputStream output = new BufferedOutputStream(new FileOutputStream(file))) {
                while (!stopped && frames < MAX_FRAMES) {
                    int count = recorder.read(samples, 0, (int) Math.min(samples.length, MAX_FRAMES - frames), AudioRecord.READ_BLOCKING);
                    if (count <= 0) throw new IOException("Microphone read failed: " + count);
                    meterUpdate.accept(meter.level(samples, count));
                    floats.clear();
                    for (int index = 0; index < count; index++) floats.putFloat(samples[index] / 32768.0f);
                    output.write(floats.array(), 0, count * Float.BYTES);
                    frames += count;
                }
            }
            if (frames == 0) throw new IOException("No captured frames");
        } finally {
            if (recorder.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) recorder.stop();
            recorder.release();
        }
    }
}
