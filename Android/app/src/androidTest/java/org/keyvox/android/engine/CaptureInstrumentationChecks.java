package org.keyvox.android.engine;

import android.app.Instrumentation;
import android.content.Intent;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.function.BooleanSupplier;
import org.keyvox.android.app.KeyVoxActivity;
import org.keyvox.android.app.KeyVoxApplication;
import org.keyvox.android.dictation.DictationSession;

/** Real microphone ownership checks; these require an unlocked, authorized device. */
public final class CaptureInstrumentationChecks {
    private CaptureInstrumentationChecks() {}

    public static void run(Instrumentation runner) throws Exception {
        runner.startActivitySync(new Intent(runner.getTargetContext(), KeyVoxActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        runner.waitForIdleSync();
        DictationSession session = KeyVoxApplication.dictation(runner.getTargetContext());
        await(runner, session, () -> session.canStart());
        try {
            for (int attempt = 0; attempt < 2; attempt++) {
                runner.runOnMainSync(session::start);
                await(runner, session, () -> session.phase() == DictationSession.Phase.RECORDING);
                runner.runOnMainSync(session::cancel);
                await(runner, session, () -> session.phase() == DictationSession.Phase.IDLE);
            }
            runner.runOnMainSync(session::start);
            await(runner, session, () -> session.phase() == DictationSession.Phase.RECORDING);
            // Collect a short real stream before exercising Stop and inference ownership.
            Thread.sleep(500);
            runner.runOnMainSync(session::stop);
            await(runner, session, () -> session.phase() == DictationSession.Phase.IDLE);
        } finally { runner.runOnMainSync(session::cancel); }
    }

    private static void await(Instrumentation runner, DictationSession session, BooleanSupplier condition) throws Exception {
        CountDownLatch ready = new CountDownLatch(1);
        Runnable observer = () -> { if (condition.getAsBoolean()) ready.countDown(); };
        runner.runOnMainSync(() -> session.observe(observer));
        boolean completed = ready.await(45, TimeUnit.SECONDS);
        runner.runOnMainSync(() -> session.removeObserver(observer));
        if (!completed) throw new AssertionError("Capture lifecycle timed out");
    }
}
