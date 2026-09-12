package android.media;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/** Deterministic ownership test double, not a microphone implementation. */
public final class AudioRecord {
    public static final int STATE_INITIALIZED = 1;
    public static final int RECORDSTATE_RECORDING = 2;
    public static final int READ_BLOCKING = 0;
    public static final AtomicInteger starts = new AtomicInteger();
    public static final AtomicInteger releases = new AtomicInteger();
    public static final AtomicInteger constructions = new AtomicInteger();
    public static final CountDownLatch initialized = new CountDownLatch(1);
    public static final CountDownLatch reading = new CountDownLatch(1);
    public static CountDownLatch allowInitialization = new CountDownLatch(0);
    public static final CountDownLatch allowRead = new CountDownLatch(1);
    public static boolean failRead;
    public static boolean failRelease;
    private boolean recording;

    public AudioRecord(int source, int rate, int channels, int encoding, int size) {
        constructions.incrementAndGet();
        initialized.countDown();
        await(allowInitialization);
    }
    public static void await(CountDownLatch latch) {
        try {
            if (!latch.await(10, TimeUnit.SECONDS)) throw new AssertionError("Latch timed out");
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            throw new AssertionError(error);
        }
    }
    public static int getMinBufferSize(int rate, int channels, int encoding) { return 4; }
    public int getState() { return STATE_INITIALIZED; }
    public void startRecording() { starts.incrementAndGet(); recording = true; }
    public int getRecordingState() { return recording ? RECORDSTATE_RECORDING : 0; }
    public int read(short[] buffer, int offset, int length, int mode) {
        reading.countDown();
        await(allowRead);
        if (failRead) return -1;
        buffer[offset] = Short.MIN_VALUE; buffer[offset + 1] = Short.MAX_VALUE;
        return 2;
    }
    public void stop() { recording = false; }
    public void release() {
        releases.incrementAndGet();
        if (failRelease) throw new IllegalStateException("Simulated release failure");
    }
}
