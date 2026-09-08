package org.keyvox.android.ime;

import android.content.Context;
import android.widget.Button;
import android.widget.LinearLayout;
import org.keyvox.android.R;

/** Replaceable presentation for exercising the IME connection. */
final class KeyboardShellView extends LinearLayout {
    private final Button dictation;
    private final Button cancel;
    KeyboardShellView(Context context, Runnable open, Runnable next, Runnable delete, Runnable space, Runnable enter,
            Runnable toggleDictation, Runnable cancelDictation) {
        super(context);
        setOrientation(VERTICAL);
        setOnApplyWindowInsetsListener((view, insets) -> {
            int bottom = insets.getSystemWindowInsetBottom();
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                bottom = insets.getInsetsIgnoringVisibility(android.view.WindowInsets.Type.navigationBars()).bottom;
            }
            view.setPadding(view.getPaddingLeft(), view.getPaddingTop(), view.getPaddingRight(), bottom);
            android.util.Log.d("KeyVoxKeyboardInsets", "navigationBottom=" + bottom);
            return insets;
        });
        addAction(R.string.open_app, open);
        addAction(R.string.next_keyboard, next);
        LinearLayout speech = new LinearLayout(context);
        addView(speech);
        dictation = addAction(speech, R.string.start_dictation, toggleDictation);
        cancel = addAction(speech, R.string.cancel_dictation, cancelDictation);
        LinearLayout editing = new LinearLayout(context);
        addView(editing);
        addAction(editing, R.string.delete_key, delete);
        addAction(editing, R.string.space_key, space);
        addAction(editing, R.string.enter_key, enter);
    }

    void render(org.keyvox.android.dictation.DictationSession session) {
        boolean recording = session.phase() == org.keyvox.android.dictation.DictationSession.Phase.RECORDING
            || session.phase() == org.keyvox.android.dictation.DictationSession.Phase.STARTING;
        boolean processing = session.phase() == org.keyvox.android.dictation.DictationSession.Phase.PROCESSING;
        boolean cancelling = session.phase() == org.keyvox.android.dictation.DictationSession.Phase.CANCELLING;
        dictation.setText(recording ? R.string.stop_dictation : processing ? R.string.processing_dictation : R.string.start_dictation);
        dictation.setEnabled(!processing && !cancelling);
        cancel.setEnabled(recording || processing);
    }

    private void addAction(int label, Runnable action) { addAction(this, label, action); }

    private Button addAction(LinearLayout parent, int label, Runnable action) {
        Button button = new Button(getContext());
        button.setText(label);
        button.setOnClickListener(view -> action.run());
        parent.addView(button);
        return button;
    }
}
