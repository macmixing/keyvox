package org.keyvox.android.accessibility;

import android.view.accessibility.AccessibilityNodeInfo;
import org.keyvox.android.engine.NativeEngine;

/** Computes one complete editor value and cursor position for an accessibility insertion. */
final class AccessibilityTextEdit {
    private static final int SURROUNDING_TEXT_LIMIT = 2048;
    final String text;
    final int cursor;

    private AccessibilityTextEdit(String text, int cursor) {
        this.text = text;
        this.cursor = cursor;
    }

    static AccessibilityTextEdit create(AccessibilityNodeInfo node, String transcript) {
        if (transcript == null || transcript.isEmpty()) return null;
        CharSequence nodeText = node.getText();
        String current = nodeText == null || node.isShowingHintText()
            ? ""
            : nodeText.toString();
        int start = node.getTextSelectionStart();
        int end = node.getTextSelectionEnd();
        if (start < 0 || end < 0 || start > current.length() || end > current.length()) {
            start = current.length();
            end = current.length();
        }
        if (start > end) {
            int swap = start;
            start = end;
            end = swap;
        }

        int precedingStart = Math.max(0, start - SURROUNDING_TEXT_LIMIT);
        int followingEnd = Math.min(current.length(), end + SURROUNDING_TEXT_LIMIT);
        String preceding = current.substring(precedingStart, start);
        String following = current.substring(end, followingEnd);
        if (!preceding.isEmpty() && Character.isLowSurrogate(preceding.charAt(0))) {
            preceding = preceding.substring(1);
            precedingStart++;
        }
        if (!following.isEmpty()
                && Character.isHighSurrogate(following.charAt(following.length() - 1))) {
            following = following.substring(0, following.length() - 1);
            followingEnd--;
        }

        NativeEngine.Composition composition = NativeEngine.compose(
            transcript,
            preceding,
            precedingStart > 0,
            following,
            followingEnd < current.length()
        );
        if (composition == null || composition.text.isEmpty()) return null;

        int suffixStart = end;
        if (composition.deleteFollowingCodePoint && suffixStart < current.length()) {
            suffixStart += Character.charCount(current.codePointAt(suffixStart));
        }
        String updated = current.substring(0, start) + composition.text + current.substring(suffixStart);
        return new AccessibilityTextEdit(updated, start + composition.text.length());
    }
}
