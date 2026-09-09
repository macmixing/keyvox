package org.keyvox.android.ime;

import android.content.Intent;
import android.content.res.Configuration;
import android.inputmethodservice.InputMethodService;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import org.keyvox.android.app.KeyVoxActivity;
import org.keyvox.android.app.KeyVoxApplication;
import org.keyvox.android.dictation.DictationSession;

/** Android editor lifecycle adapter; the view owns neither capture nor inference. */
public final class KeyVoxInputMethodService extends InputMethodService {
    private final EditorConnectionOwner editor = new EditorConnectionOwner();
    private DictationSession session;
    private KeyboardShellView shell;
    private long destination;
    private long request = -1;
    private long scheduledRetryDestination = -1;
    private long scheduledRetryRequest = -1;
    private Handler mainHandler;
    private final Runnable changed = this::render;
    private final Runnable retryPendingDeletion = this::retryPendingDeletion;

    @Override public void onCreate() {
        super.onCreate();
        mainHandler = new Handler(Looper.getMainLooper());
        session = KeyVoxApplication.dictation(this);
        session.observe(changed);
    }

    @Override public void onDestroy() {
        session.removeObserver(changed);
        mainHandler.removeCallbacks(retryPendingDeletion);
        super.onDestroy();
    }

    private void openApp() {
        startActivity(new Intent(this, KeyVoxActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
    }

    private void toggleDictation() {
        if (session.phase() == DictationSession.Phase.RECORDING || session.phase() == DictationSession.Phase.STARTING) {
            session.stop();
        } else if (session.canStart()) {
            destination = editor.generation();
            request = session.start();
        } else openApp();
    }

    private void render() {
        if (shell != null) shell.render(session);
        if (request == session.request() && session.result() != null) {
            if (editor.commitDictation(destination, request, session.result())) {
                long completed = request;
                request = -1;
                scheduledRetryDestination = -1;
                scheduledRetryRequest = -1;
                session.acknowledgeResult(completed);
            } else if (editor.hasPendingDictation(destination, request)
                    && (scheduledRetryDestination != destination
                        || scheduledRetryRequest != request)) {
                scheduledRetryDestination = destination;
                scheduledRetryRequest = request;
                mainHandler.post(retryPendingDeletion);
            }
        }
    }

    private void retryPendingDeletion() {
        if (request != scheduledRetryRequest || destination != scheduledRetryDestination) return;
        if (editor.hasPendingDictation(destination, request)) {
            render();
            return;
        }

        long completed = request;
        request = -1;
        scheduledRetryDestination = -1;
        scheduledRetryRequest = -1;
        session.acknowledgeResult(completed);
    }

    @Override public void onStartInput(EditorInfo info, boolean restarting) {
        super.onStartInput(info, restarting);
        editor.attach(getCurrentInputConnection());
    }

    @Override public void onFinishInput() {
        editor.detach();
        super.onFinishInput();
    }

    @Override public boolean onEvaluateFullscreenMode() { return false; }

    @Override public void onConfigurationChanged(Configuration configuration) {
        super.onConfigurationChanged(configuration);
        if (shell != null) shell.refreshAppearance();
    }

    @Override public View onCreateInputView() {
        shell = new KeyboardShellView(this,
            () -> switchToNextInputMethod(false),
            editor::deletePreviousCodePoint,
            text -> editor.commit(editor.generation(), text),
            this::toggleDictation,
            () -> session.cancel());
        render();
        return shell;
    }
}
