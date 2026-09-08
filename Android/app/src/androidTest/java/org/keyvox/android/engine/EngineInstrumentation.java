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
    private int rounds;
    private long leadInMilliseconds;
    private boolean installModel;
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        fixture = arguments == null ? null : arguments.getString("fixture");
        captureChecks = arguments != null && "true".equals(arguments.getString("capture"));
        installModel = arguments != null && "true".equals(arguments.getString("installModel"));
        rounds = arguments == null ? 1 : Integer.parseInt(arguments.getString("rounds", "1"));
        leadInMilliseconds = arguments == null ? 0 : Long.parseLong(arguments.getString("leadInMilliseconds", "0"));
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
            if (installModel) {
                CountDownLatch installed = new CountDownLatch(1);
                Runnable installation = () -> {
                    if (session.model() != DictationSession.Model.DOWNLOADING) installed.countDown();
                };
                runOnMainSync(() -> { session.downloadModel(); session.observe(installation); });
                boolean finished = installed.await(300, TimeUnit.SECONDS);
                runOnMainSync(() -> session.removeObserver(installation));
                if (!finished) throw new AssertionError("Model installation timed out");
            }
            if (rounds < 1 || rounds > 10) throw new AssertionError("Invalid benchmark repeat count");
            if (leadInMilliseconds < 0 || leadInMilliseconds > 30_000) throw new AssertionError("Invalid benchmark lead-in");
            // Models setup/recording time without including that delay in processing measurements.
            Thread.sleep(leadInMilliseconds);
            StringBuilder timings = new StringBuilder();
            String expectedText = null;
            for (int round = 0; round < rounds; round++) {
                final int request = 101 + round;
                CountDownLatch completed = new CountDownLatch(1);
                AtomicReference<JSONObject> response = new AtomicReference<>();
                runOnMainSync(() -> NativeEngine.setListener(json -> {
                    try {
                        JSONObject event = new JSONObject(json);
                        if (event.optLong("request", -1) == request) { response.set(event); completed.countDown(); }
                    } catch (Exception error) { throw new AssertionError(error); }
                }));
                runOnMainSync(() -> NativeEngine.transcribe(input.getPath(), request));
                if (!completed.await(90, TimeUnit.SECONDS)) throw new AssertionError("Engine completion timed out");
                JSONObject event = response.get();
                if (!event.getString("kind").equals("result") || event.optString("text").trim().isEmpty()) {
                    throw new AssertionError("Expected processed speech output");
                }
                if (expectedText == null) expectedText = event.getString("text");
                else if (!expectedText.equals(event.getString("text"))) throw new AssertionError("Repeated output changed");
                for (String field : new String[] { "audioReadMilliseconds", "modelWarmupMilliseconds",
                        "inferenceMilliseconds", "pipelineMilliseconds", "postProcessorPreparationWaitMilliseconds" }) {
                    double value = event.getDouble(field);
                    if (!Double.isFinite(value) || value < 0) throw new AssertionError("Invalid timing: " + field);
                }
                event.remove("text");
                timings.append("KV_PIPELINE ").append(event).append('\n');
            }
            result.putString("stream", timings + "Installed Swift engine fixture passed; output characters=" + expectedText.length());
            result.putString("outputSHA256", android.util.Base64.encodeToString(
                java.security.MessageDigest.getInstance("SHA-256").digest(expectedText.getBytes(java.nio.charset.StandardCharsets.UTF_8)),
                android.util.Base64.NO_WRAP));
            finish(Activity.RESULT_OK, result);
        } catch (Exception | AssertionError error) {
            result.putString("stream", "Engine fixture failed: " + error);
            finish(Activity.RESULT_CANCELED, result);
        }
    }
}
