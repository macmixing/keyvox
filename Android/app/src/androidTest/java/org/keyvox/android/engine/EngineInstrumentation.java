package org.keyvox.android.engine;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.Bundle;
import org.json.JSONObject;
import java.io.File;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.keyvox.android.app.KeyVoxApplication;
import org.keyvox.android.app.KeyVoxActivity;
import android.content.Intent;
import org.keyvox.android.dictation.DictationSession;

/** Executes a caller-provided local PCM fixture through the installed Swift engine. */
public class EngineInstrumentation extends Instrumentation {
    protected String fixture;
    protected boolean captureChecks;
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        fixture = arguments == null ? null : arguments.getString("fixture");
        captureChecks = arguments != null && "true".equals(arguments.getString("capture"));
        start();
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            startActivitySync(new Intent(getTargetContext(), KeyVoxActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            File input = new File(getTargetContext().getFilesDir(), fixture);
            if (!input.isFile()) throw new AssertionError("Missing caller-provided PCM fixture");
            DictationSession session = KeyVoxApplication.dictation(getTargetContext());
            CountDownLatch ready = new CountDownLatch(1);
            Runnable initialized = () -> { if (session.model() == DictationSession.Model.READY) ready.countDown(); };
            runOnMainSync(() -> session.observe(initialized));
            boolean available = ready.await(30, TimeUnit.SECONDS);
            runOnMainSync(() -> session.removeObserver(initialized));
            if (!available) throw new AssertionError("Installed model was not ready");
            CountDownLatch completed = new CountDownLatch(1);
            AtomicReference<JSONObject> response = new AtomicReference<>();
            runOnMainSync(() -> NativeEngine.setListener(json -> {
                try {
                    JSONObject event = new JSONObject(json);
                    if (event.optLong("request", -1) == 101) { response.set(event); completed.countDown(); }
                } catch (Exception error) { throw new AssertionError(error); }
            }));
            runOnMainSync(() -> NativeEngine.transcribe(input.getPath(), 101));
            if (!completed.await(90, TimeUnit.SECONDS)) throw new AssertionError("Engine completion timed out");
            JSONObject event = response.get();
            if (!event.getString("kind").equals("result") || event.optString("text").trim().isEmpty()) {
                throw new AssertionError("Expected processed speech output: " + event);
            }
            result.putString("stream", "Installed Swift engine fixture passed; output characters=" + event.getString("text").length());
            finish(Activity.RESULT_OK, result);
        } catch (Exception | AssertionError error) {
            result.putString("stream", "Engine fixture failed: " + error);
            finish(Activity.RESULT_CANCELED, result);
        }
    }
}
