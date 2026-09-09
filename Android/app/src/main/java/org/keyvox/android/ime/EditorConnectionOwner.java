package org.keyvox.android.ime;

import android.view.inputmethod.InputConnection;

/** Only the IME owns editor access; an old destination cannot accept a late result. */
final class EditorConnectionOwner {
    private long generation;
    private InputConnection connection;

    long attach(InputConnection current) {
        generation++;
        connection = current;
        return generation;
    }

    void detach() {
        generation++;
        connection = null;
    }

    long generation() { return generation; }

    boolean commit(long destination, CharSequence text) {
        return destination == generation && connection != null && connection.commitText(text, 1);
    }

    boolean commitDictation(long destination, CharSequence text) {
        // A no-speech completion must not erase the editor's current selection.
        return text.length() == 0 || commit(destination, text);
    }

    boolean deletePreviousCodePoint() {
        if (connection == null) return false;
        CharSequence selected = connection.getSelectedText(0);
        if (selected != null && selected.length() > 0) return connection.commitText("", 1);

        CharSequence preceding = connection.getTextBeforeCursor(2, 0);
        if (preceding == null || preceding.length() == 0) return false;
        return connection.deleteSurroundingTextInCodePoints(1, 0);
    }
}
