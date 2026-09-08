package org.keyvox.android.ime;

import android.content.Context;
import android.widget.Button;
import android.widget.LinearLayout;
import org.keyvox.android.R;

/** Replaceable presentation for exercising the IME connection. */
final class KeyboardShellView extends LinearLayout {
    KeyboardShellView(Context context, Runnable open, Runnable next, Runnable delete, Runnable space, Runnable enter) {
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
        LinearLayout editing = new LinearLayout(context);
        addView(editing);
        addAction(editing, R.string.delete_key, delete);
        addAction(editing, R.string.space_key, space);
        addAction(editing, R.string.enter_key, enter);
    }

    private void addAction(int label, Runnable action) { addAction(this, label, action); }

    private void addAction(LinearLayout parent, int label, Runnable action) {
        Button button = new Button(getContext());
        button.setText(label);
        button.setOnClickListener(view -> action.run());
        parent.addView(button);
    }
}
