package org.keyvox.android.dictation;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import org.json.JSONObject;
import org.keyvox.android.engine.EngineResources;
import org.keyvox.android.engine.NativeEngine;

/** Process-owned operations and state. Activities and keyboard views only observe it. */
public final class DictationSession {
    public enum Phase { INITIALIZING, IDLE, STARTING, RECORDING, PROCESSING, CANCELLING, FAILED }
    public enum Model { CHECKING, MISSING, DOWNLOADING, READY, FAILED }
    private final Context context;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Consumer<String> successfulTranscription;
    private final BooleanSupplier autoParagraphsEnabled;
    private final BooleanSupplier listFormattingEnabled;
    private final List<Runnable> observers = new ArrayList<>();
    private Phase phase = Phase.INITIALIZING;
    private Model model = Model.CHECKING;
    private long request;
    private File audio;
    private DictationResult result;
    private boolean initialized;
    private boolean optionalModelAvailable;
    private boolean captureActive;
    private boolean awaitingEngineCancellation;
    private float audioLevel;

    public DictationSession(
        Context context,
        Consumer<String> successfulTranscription,
        BooleanSupplier autoParagraphsEnabled,
        BooleanSupplier listFormattingEnabled
    ) {
        this.context = context.getApplicationContext();
        this.successfulTranscription = successfulTranscription;
        this.autoParagraphsEnabled = autoParagraphsEnabled;
        this.listFormattingEnabled = listFormattingEnabled;
    }
    public Phase phase() { return phase; }
    public Model model() { return model; }
    public boolean canDownloadModel() {
        return initialized && (phase == Phase.IDLE || phase == Phase.FAILED)
            && (model == Model.MISSING || model == Model.FAILED || (model == Model.READY && optionalModelAvailable));
    }
    public long request() { return request; }
    public DictationResult result() { return result; }
    public float audioLevel() { return audioLevel; }
    public void observe(Runnable observer) { observers.add(observer); observer.run(); }
    public void removeObserver(Runnable observer) { observers.remove(observer); }

    public void initializeEngine() {
        new Thread(() -> {
            try {
                File resources = EngineResources.prepare(context);
                org.keyvox.android.engine.AccelerationRuntime.prepare(resources);
                main.post(() -> {
                    try {
                        if (!NativeEngine.initialize(resources.getPath(),
                                new File(context.getFilesDir(), "models").getPath(),
                                new File(context.getFilesDir(), "dictionary").getPath(),
                                context.getApplicationInfo().nativeLibraryDir,
                                android.os.Build.VERSION.SDK_INT >= 31 ? android.os.Build.SOC_MODEL : "",
                                org.keyvox.android.BuildConfig.VERSION_NAME,
                                autoParagraphsEnabled.getAsBoolean(),
                                listFormattingEnabled.getAsBoolean())) fail();
                    } catch (LinkageError | RuntimeException error) { Log.e("KeyVoxEngine", "Initialization failed", error); fail(); }
                });
            } catch (Exception error) { Log.e("KeyVoxEngine", "Resource installation failed", error); main.post(this::fail); }
        }, "KeyVoxResources").start();
    }

    public boolean canStart() {
        return initialized && model == Model.READY && (phase == Phase.IDLE || phase == Phase.FAILED)
            && context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
    }

    public long start() {
        if (!canStart()) return -1;
        request++;
        result = null;
        audioLevel = 0;
        phase = Phase.STARTING;
        captureActive = true;
        publish();
        try {
            context.startForegroundService(new Intent(context, DictationCaptureService.class)
                .setAction(DictationCaptureService.START).putExtra(DictationCaptureService.REQUEST, request));
        } catch (RuntimeException error) { captureActive = false; Log.e("KeyVoxCapture", "Start rejected", error); fail(); }
        return request;
    }

    public void stop() {
        if (phase != Phase.RECORDING && phase != Phase.STARTING) return;
        phase = Phase.PROCESSING;
        publish();
        context.startService(new Intent(context, DictationCaptureService.class).setAction(DictationCaptureService.STOP));
    }

    public void cancel() {
        if (phase == Phase.RECORDING || phase == Phase.STARTING || phase == Phase.PROCESSING) {
            phase = Phase.CANCELLING;
            awaitingEngineCancellation = true;
            result = null;
            publish();
            context.stopService(new Intent(context, DictationCaptureService.class));
            NativeEngine.cancel();
        }
    }

    public void downloadModel() {
        if (!initialized || (phase != Phase.IDLE && phase != Phase.FAILED) || model == Model.DOWNLOADING) return;
        model = Model.DOWNLOADING;
        publish();
        NativeEngine.download();
    }

    void recording(long id) {
        if (id != request || phase != Phase.STARTING) return;
        phase = Phase.RECORDING;
        publish();
    }

    void audioLevel(long id, float level) {
        if (id != request || (phase != Phase.STARTING && phase != Phase.RECORDING)) return;
        audioLevel = Math.min(Math.max(level, 0), 1);
        publish();
    }

    void captured(long id, File file) {
        if (id == request) captureActive = false;
        if (id == request) audioLevel = 0;
        if (id == request && phase == Phase.CANCELLING) {
            if (file != null) file.delete();
            finishCancellation();
            return;
        }
        if (id != request || (phase != Phase.RECORDING && phase != Phase.PROCESSING && phase != Phase.STARTING)) {
            if (file != null) file.delete();
            return;
        }
        if (file == null) { fail(); return; }
        audio = file;
        phase = Phase.PROCESSING;
        publish();
        NativeEngine.transcribe(file.getPath(), id);
    }

    public void acknowledgeResult(long id) {
        if (request == id) { result = null; publish(); }
    }

    public void receive(String json) {
        try {
            JSONObject event = new JSONObject(json);
            String kind = event.getString("kind");
            if (event.has("optionalModelAvailable")) optionalModelAvailable = event.getBoolean("optionalModelAvailable");
            switch (kind) {
                case "configured":
                    initialized = true;
                    model = event.optBoolean("modelReady") ? Model.READY : Model.MISSING;
                    phase = Phase.IDLE;
                    break;
                case "modelDownloading": model = Model.DOWNLOADING; break;
                case "modelReady": model = Model.READY; break;
                case "modelFailed": model = event.optBoolean("modelReady") ? Model.READY : Model.FAILED; break;
                case "result":
                    if (phase == Phase.CANCELLING) return;
                    if (event.optLong("request", -1) != request) return;
                    result = DictationResult.from(event);
                    if (!event.optBoolean("noSpeech") && !result.text().trim().isEmpty()) {
                        successfulTranscription.accept(result.text());
                    }
                    clearAudio();
                    phase = Phase.IDLE;
                    break;
                case "failed":
                    if (phase == Phase.CANCELLING) return;
                    if (event.has("request") && event.getLong("request") != request) return;
                    fail();
                    return;
                case "cancelled":
                    awaitingEngineCancellation = false;
                    finishCancellation();
                    return;
                default: return;
            }
            Log.i("KeyVoxEngine", "event=" + kind + " phase=" + phase + " model=" + model);
            publish();
        } catch (Exception error) { Log.e("KeyVoxEngine", "Invalid engine event", error); fail(); }
    }

    private void clearAudio() { if (audio != null) { audio.delete(); audio = null; } }
    private void finishCancellation() {
        if (phase != Phase.CANCELLING || captureActive || awaitingEngineCancellation) return;
        clearAudio();
        request++;
        phase = Phase.IDLE;
        publish();
    }
    private void fail() { clearAudio(); audioLevel = 0; phase = Phase.FAILED; publish(); }
    private void publish() {
        Log.i("KeyVoxSession", "request=" + request + " phase=" + phase + " capture=" + captureActive);
        for (Runnable observer : new ArrayList<>(observers)) observer.run();
    }
}
