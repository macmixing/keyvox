package org.keyvox.android.debug;

import android.app.Activity;
import android.os.Bundle;
import android.widget.EditText;
import org.keyvox.android.R;

/** Debug-only editor host, never part of the containing app's product surface. */
public final class EditorTestActivity extends Activity {
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        EditText editor = new EditText(this);
        editor.setHint(R.string.editor_hint);
        editor.setGravity(android.view.Gravity.TOP);
        editor.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        editor.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(),
                insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            return insets;
        });
        setContentView(editor);
    }
}
