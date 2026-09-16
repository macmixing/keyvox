package org.keyvox.android.accessibility;

import android.app.AlertDialog;
import android.content.Context;
import org.keyvox.android.R;

/** Presents the required in-app disclosure before opening accessibility settings. */
public final class AccessibilityDisclosureDialog {
    private AccessibilityDisclosureDialog() {}

    public static void show(Context context, Runnable continueAction) {
        new AlertDialog.Builder(context)
            .setTitle(R.string.dictation_bubble_disclosure_title)
            .setMessage(R.string.dictation_bubble_disclosure_message)
            .setNegativeButton(R.string.cancel, null)
            .setPositiveButton(R.string.continue_action, (dialog, which) -> continueAction.run())
            .show();
    }
}
