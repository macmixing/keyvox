package org.keyvox.android.app;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import org.keyvox.android.dictation.DictationSession;
import org.keyvox.android.R;

/** Minimal host surface. Dictation lifetime must never belong to this Activity. */
public final class KeyVoxActivity extends Activity {
    private TextView status;
    private Button download;
    private final Runnable changed = this::render;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(),
                insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            return insets;
        });
        Button enable = new Button(this);
        enable.setText(R.string.enable_keyboard);
        enable.setOnClickListener(view -> startActivity(new Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)));
        content.addView(enable);
        Button select = new Button(this);
        select.setText(R.string.select_keyboard);
        select.setOnClickListener(view -> getSystemService(InputMethodManager.class).showInputMethodPicker());
        content.addView(select);
        Button permission = new Button(this);
        permission.setText(R.string.allow_microphone);
        permission.setOnClickListener(view -> requestPermissions(new String[] { android.Manifest.permission.RECORD_AUDIO }, 1));
        content.addView(permission);
        status = new TextView(this);
        content.addView(status);
        download = new Button(this);
        download.setText(R.string.download_model);
        download.setOnClickListener(view -> KeyVoxApplication.dictation(this).downloadModel());
        content.addView(download);
        setContentView(content);
    }

    @Override public void onStart() { super.onStart(); KeyVoxApplication.dictation(this).observe(changed); }
    @Override public void onStop() { KeyVoxApplication.dictation(this).removeObserver(changed); super.onStop(); }

    private void render() {
        DictationSession session = KeyVoxApplication.dictation(this);
        int label = switch (session.model()) {
            case CHECKING -> R.string.model_checking;
            case MISSING -> R.string.model_missing;
            case DOWNLOADING -> R.string.model_downloading;
            case READY -> R.string.model_ready;
            case FAILED -> R.string.model_failed;
        };
        status.setText(session.phase() == DictationSession.Phase.FAILED ? R.string.engine_failed : label);
        download.setEnabled(session.canDownloadModel());
    }
}
