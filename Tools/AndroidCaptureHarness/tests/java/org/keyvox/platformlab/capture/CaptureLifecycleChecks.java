package org.keyvox.platformlab.capture;

import android.media.AudioRecord;
import java.io.File;
import java.nio.file.Files;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;

public final class CaptureLifecycleChecks {
    private static final class Result implements AudioCapture.Listener {
        final CountDownLatch finished = new CountDownLatch(1);
        final AtomicInteger completions = new AtomicInteger();
        File file;
        Exception failure;
        public void recording() {}
        public void finished(File file, Exception failure) {
            this.file = file; this.failure = failure;
            completions.incrementAndGet(); finished.countDown();
        }
    }
    private static void require(boolean condition) {
        if (!condition) throw new AssertionError("Capture invariant failed");
    }
    public static void main(String[] args) throws Exception {
        String scenario = args[0];
        File directory = new File(args[1]);
        AudioCapture capture = new AudioCapture();
        Result result = new Result();
        boolean stopDuringStartup = scenario.equals("startup");
        if (stopDuringStartup) AudioRecord.allowInitialization = new CountDownLatch(1);
        AudioRecord.failRead = scenario.equals("read-failure");
        AudioRecord.failRelease = scenario.equals("release-failure");
        capture.start(directory, result);
        AudioRecord.await(AudioRecord.initialized);
        if (stopDuringStartup) {
            capture.start(directory, result);
            capture.stop();
            AudioRecord.allowInitialization.countDown();
        } else {
            AudioRecord.await(AudioRecord.reading);
            capture.start(directory, result);
            capture.stop();
            AudioRecord.allowRead.countDown();
        }
        AudioRecord.await(result.finished);
        require(!capture.isActive());
        require(AudioRecord.constructions.get() == 1);
        require(AudioRecord.starts.get() == (stopDuringStartup ? 0 : 1));
        require(AudioRecord.releases.get() == 1);
        require(result.completions.get() == 1);
        require(result.file != null && result.file.isFile());
        boolean partial = stopDuringStartup || AudioRecord.failRead;
        require(result.file.getName().endsWith(partial ? ".partial" : ".wav"));
        require((result.failure != null) == (partial || AudioRecord.failRelease));
        byte[] bytes = Files.readAllBytes(result.file.toPath());
        require(bytes.length == (partial ? 44 : 48));
        System.out.println(scenario + " passed");
    }
}
