package org.keyvox.android.accessibility;

import android.content.ClipData;
import android.content.ClipDescription;
import android.content.ClipboardManager;
import android.content.Context;
import android.os.Build;
import android.os.PersistableBundle;
import android.widget.Toast;
import org.keyvox.android.R;

/** Owns the privacy-aware clipboard fallback for a completed dictation. */
final class DictationClipboard {
    private static final String EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE";
    private final Context context;

    DictationClipboard(Context context) {
        this.context = context;
    }

    void copy(String text) {
        write(text);
        if (Build.VERSION.SDK_INT <= 32) {
            Toast.makeText(context, R.string.dictation_copied, Toast.LENGTH_SHORT).show();
        }
    }

    void placeForPaste(String text) {
        write(text);
    }

    private void write(String text) {
        ClipData clip = ClipData.newPlainText(context.getString(R.string.app_name), text);
        PersistableBundle extras = new PersistableBundle();
        extras.putBoolean(EXTRA_IS_SENSITIVE, true);
        clip.getDescription().setExtras(extras);
        context.getSystemService(ClipboardManager.class).setPrimaryClip(clip);
    }
}
