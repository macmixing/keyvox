package org.keyvox.android.dictation;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import java.io.File;
import org.keyvox.android.R;
import org.keyvox.android.app.KeyVoxApplication;

/** Android microphone lifetime; view visibility never stops an active recording. */
public final class DictationCaptureService extends Service {
    static final String START = "org.keyvox.android.capture.START";
    static final String STOP = "org.keyvox.android.capture.STOP";
    static final String REQUEST = "request";
    private static final String CHANNEL = "dictation";
    private final Handler main = new Handler(Looper.getMainLooper());
    private MicrophoneCapture capture;
    private boolean destroyed;
    private long request = -1;
    private boolean completed;
    private int activeStartId;
    private final Runnable sessionChanged = () -> {
        DictationSession.Phase phase = KeyVoxApplication.dictation(this).phase();
        if (completed && (phase == DictationSession.Phase.IDLE || phase == DictationSession.Phase.FAILED)) {
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf(activeStartId);
        }
    };

    @Override public void onCreate() {
        super.onCreate();
        KeyVoxApplication.dictation(this).observe(sessionChanged);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        activeStartId = startId;
        if (intent == null) { stopSelf(); return START_NOT_STICKY; }
        if (STOP.equals(intent.getAction())) {
            if (capture != null) capture.stop();
            else stopSelf();
            return START_NOT_STICKY;
        }
        if (!START.equals(intent.getAction()) || (capture != null && !completed)) return START_NOT_STICKY;
        completed = false;
        long id = intent.getLongExtra(REQUEST, -1);
        request = id;
        DictationSession session = KeyVoxApplication.dictation(this);
        try {
            NotificationManager notifications = getSystemService(NotificationManager.class);
            notifications.createNotificationChannel(new NotificationChannel(CHANNEL, getString(R.string.dictation_channel), NotificationManager.IMPORTANCE_LOW));
            startForeground(1, new Notification.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_btn_speak_now).setContentTitle(getString(R.string.app_name))
                .setContentText(getString(R.string.microphone_active)).setOngoing(true).build());
            MicrophoneCapture active = new MicrophoneCapture();
            capture = active;
            new Thread(() -> {
                File file = null;
                try {
                    File directory = new File(getFilesDir(), "captures");
                    if (!directory.isDirectory() && !directory.mkdirs()) throw new java.io.IOException("Cannot create capture directory");
                    file = File.createTempFile("capture-", ".f32", directory);
                    active.record(
                        file,
                        () -> main.post(() -> session.recording(id)),
                        level -> main.post(() -> session.audioLevel(id, level))
                    );
                } catch (Exception error) {
                    Log.e("KeyVoxCapture", "Capture failed", error);
                    if (file != null) file.delete();
                    file = null;
                }
                File completed = file;
                main.post(() -> {
                    this.completed = true;
                    if (destroyed) {
                        if (completed != null) completed.delete();
                        session.captured(id, null);
                    }
                    else {
                        startForeground(1, new Notification.Builder(this, CHANNEL)
                            .setSmallIcon(android.R.drawable.ic_btn_speak_now).setContentTitle(getString(R.string.app_name))
                            .setContentText(getString(R.string.processing_dictation)).setOngoing(true).build());
                        session.captured(id, completed);
                        sessionChanged.run();
                    }
                });
            }, "KeyVoxMicrophone").start();
        } catch (RuntimeException error) {
            Log.e("KeyVoxCapture", "Microphone service rejected", error);
            session.captured(id, null);
            completed = true;
            stopSelf();
        }
        return START_NOT_STICKY;
    }

    @Override public void onDestroy() {
        destroyed = true;
        KeyVoxApplication.dictation(this).removeObserver(sessionChanged);
        if (capture != null) capture.stop();
        if (!completed && capture == null && request >= 0) KeyVoxApplication.dictation(this).captured(request, null);
        DictationSession session = KeyVoxApplication.dictation(this);
        if (completed && session.request() == request) session.cancel();
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent) { return null; }
}
