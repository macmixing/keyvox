package org.keyvox.android.ime;

import android.content.Intent;
import android.inputmethodservice.InputMethodService;
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
    private final Runnable changed = this::render;

    @Override public void onCreate() {
        super.onCreate();
        session = KeyVoxApplication.dictation(this);
        session.observe(changed);
    }

    @Override public void onDestroy() {
        session.removeObserver(changed);
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
            if (editor.commitDictation(destination, session.result())) {
                long completed = request;
                request = -1;
                session.acknowledgeResult(completed);
            }
        }
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

    @Override public View onCreateInputView() {
        shell = new KeyboardShellView(this,
            this::openApp,
            () -> switchToNextInputMethod(false),
            () -> editor.deletePreviousCodePoint(),
            () -> editor.commit(editor.generation(), " "),
            () -> editor.commit(editor.generation(), "\n"), this::toggleDictation, () -> session.cancel());
        render();
        return shell;
    }
}
