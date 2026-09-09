package org.keyvox.android.ime;

import android.view.inputmethod.ExtractedText;
import android.view.inputmethod.InputConnection;
import java.lang.reflect.Proxy;

/** Mutable UTF-16 editor fixture backed by the platform InputConnection contract. */
final class EditorBufferConnection {
    private final StringBuilder text;
    private int selectionStart;
    private int selectionEnd;
    private boolean surroundingTextAvailable = true;
    private boolean extractedTextAvailable = true;
    private int surroundingTextCap = Integer.MAX_VALUE;
    private boolean codePointDeletionAvailable = true;
    private boolean utf16DeletionAvailable = true;
    final InputConnection connection;

    EditorBufferConnection(String text, int selectionStart, int selectionEnd) {
        this.text = new StringBuilder(text);
        this.selectionStart = selectionStart;
        this.selectionEnd = selectionEnd;
        connection = (InputConnection) Proxy.newProxyInstance(
            InputConnection.class.getClassLoader(),
            new Class<?>[] {InputConnection.class},
            (proxy, method, args) -> {
                switch (method.getName()) {
                    case "beginBatchEdit":
                    case "endBatchEdit":
                        return true;
                    case "getSelectedText":
                        return this.text.substring(this.selectionStart, this.selectionEnd);
                    case "getTextBeforeCursor": {
                        if (!surroundingTextAvailable) return null;
                        int count = Math.min((int) args[0], surroundingTextCap);
                        int start = Math.max(0, this.selectionStart - count);
                        return this.text.substring(start, this.selectionStart);
                    }
                    case "getTextAfterCursor": {
                        if (!surroundingTextAvailable) return null;
                        int count = Math.min((int) args[0], surroundingTextCap);
                        int end = Math.min(this.text.length(), this.selectionEnd + count);
                        return this.text.substring(this.selectionEnd, end);
                    }
                    case "getExtractedText": {
                        if (!extractedTextAvailable) return null;
                        ExtractedText extracted = new ExtractedText();
                        extracted.text = this.text.toString();
                        extracted.startOffset = 0;
                        extracted.selectionStart = this.selectionStart;
                        extracted.selectionEnd = this.selectionEnd;
                        return extracted;
                    }
                    case "commitText": {
                        String replacement = args[0].toString();
                        this.text.replace(this.selectionStart, this.selectionEnd, replacement);
                        this.selectionStart += replacement.length();
                        this.selectionEnd = this.selectionStart;
                        return true;
                    }
                    case "deleteSurroundingTextInCodePoints": {
                        if (!codePointDeletionAvailable) return false;
                        int before = (int) args[0];
                        int after = (int) args[1];
                        int start = Character.offsetByCodePoints(this.text, this.selectionStart, -before);
                        int end = Character.offsetByCodePoints(this.text, this.selectionEnd, after);
                        this.text.delete(start, end);
                        this.selectionStart = start;
                        this.selectionEnd = start;
                        return true;
                    }
                    case "deleteSurroundingText": {
                        if (!utf16DeletionAvailable) return false;
                        int before = (int) args[0];
                        int after = (int) args[1];
                        int start = Math.max(0, this.selectionStart - before);
                        int end = Math.min(this.text.length(), this.selectionEnd + after);
                        this.text.delete(start, end);
                        this.selectionStart = start;
                        this.selectionEnd = start;
                        return true;
                    }
                    default:
                        throw new AssertionError(method.getName());
                }
            });
    }

    void setSurroundingTextAvailable(boolean available) {
        surroundingTextAvailable = available;
        extractedTextAvailable = available;
    }

    void setSurroundingTextCap(int limit) {
        surroundingTextCap = limit;
    }

    void setExtractedTextAvailable(boolean available) {
        extractedTextAvailable = available;
    }

    void setSelection(int start, int end) {
        selectionStart = start;
        selectionEnd = end;
    }

    void setCodePointDeletionAvailable(boolean available) {
        codePointDeletionAvailable = available;
    }

    void setUtf16DeletionAvailable(boolean available) {
        utf16DeletionAvailable = available;
    }

    String text() {
        return text.toString();
    }
}
