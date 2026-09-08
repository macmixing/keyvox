package org.keyvox.android.ime;

import android.content.Intent;
import android.inputmethodservice.InputMethodService;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import org.keyvox.android.app.KeyVoxActivity;

/** Android editor lifecycle adapter; the view owns neither capture nor inference. */
public final class KeyVoxInputMethodService extends InputMethodService {
    private final EditorConnectionOwner editor = new EditorConnectionOwner();

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
        return new KeyboardShellView(this,
            () -> startActivity(new Intent(this, KeyVoxActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)),
            () -> switchToNextInputMethod(false),
            () -> editor.deletePreviousCodePoint(),
            () -> editor.commit(editor.generation(), " "),
            () -> editor.commit(editor.generation(), "\n"));
    }
}
