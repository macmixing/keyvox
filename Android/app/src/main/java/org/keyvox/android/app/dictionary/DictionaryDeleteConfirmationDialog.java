package org.keyvox.android.app.dictionary;

import android.app.AlertDialog;
import android.content.Context;
import org.keyvox.android.R;

/** Destructive confirmation used by every dictionary delete entry point. */
final class DictionaryDeleteConfirmationDialog {
    private DictionaryDeleteConfirmationDialog() {}

    static void show(Context context, Runnable delete) {
        AlertDialog dialog = new AlertDialog.Builder(context)
            .setTitle(R.string.dictionary_delete_title)
            .setMessage(R.string.dictionary_delete_message)
            .setNegativeButton(R.string.cancel, null)
            .setPositiveButton(R.string.dictionary_delete_action, (ignored, which) -> delete.run())
            .create();
        dialog.setOnShowListener(ignored -> dialog.getButton(AlertDialog.BUTTON_POSITIVE)
            .setTextColor(context.getColor(R.color.app_error)));
        dialog.show();
    }
}
