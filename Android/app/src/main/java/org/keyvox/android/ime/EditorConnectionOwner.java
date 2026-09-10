package org.keyvox.android.ime;

import android.view.inputmethod.InputConnection;
import android.view.inputmethod.ExtractedText;
import android.view.inputmethod.ExtractedTextRequest;
import org.keyvox.android.engine.NativeEngine;

/** Only the IME owns editor access; an old destination cannot accept a late result. */
final class EditorConnectionOwner {
    private static final int SURROUNDING_TEXT_LIMIT = 2048;

    private static final class EditorContext {
        final String precedingText;
        final boolean precedingTextIsTruncated;
        final String followingText;
        final boolean followingTextIsTruncated;

        EditorContext(
                String precedingText,
                boolean precedingTextIsTruncated,
                String followingText,
                boolean followingTextIsTruncated) {
            this.precedingText = precedingText;
            this.precedingTextIsTruncated = precedingTextIsTruncated;
            this.followingText = followingText;
            this.followingTextIsTruncated = followingTextIsTruncated;
        }
    }

    private long generation;
    private InputConnection connection;
    private long pendingDeletionGeneration = -1;
    private long pendingDeletionRequest = -1;
    private String pendingDeletionTranscript;
    private String pendingInsertedText;
    private String pendingFollowingCodePoint;

    long attach(InputConnection current) {
        generation++;
        connection = current;
        clearPendingDeletion();
        return generation;
    }

    void detach() {
        generation++;
        connection = null;
        clearPendingDeletion();
    }

    long generation() { return generation; }

    boolean commit(long destination, CharSequence text) {
        clearPendingDeletion();
        return destination == generation && connection != null && connection.commitText(text, 1);
    }

    boolean commitDictation(long destination, long request, CharSequence text) {
        // A no-speech completion must not erase the editor's current selection.
        if (text.length() == 0) return true;
        if (destination != generation || connection == null) return false;
        String transcript = text.toString();
        if (pendingDeletionGeneration == destination) {
            if (request != pendingDeletionRequest
                    || !transcript.equals(pendingDeletionTranscript)) {
                clearPendingDeletion();
            } else if (!pendingDeletionContextStillMatches()) {
                clearPendingDeletion();
                return true;
            } else if (!deleteFollowingCodePoint(pendingFollowingCodePoint.length())) {
                return false;
            } else {
                clearPendingDeletion();
                return true;
            }
        }

        EditorContext context = readEditorContext();
        NativeEngine.Composition composition = NativeEngine.compose(
            transcript,
            context.precedingText,
            context.precedingTextIsTruncated,
            context.followingText,
            context.followingTextIsTruncated);
        if (composition == null) return false;
        if (composition.text.isEmpty()) return true;

        connection.beginBatchEdit();
        try {
            boolean inserted = connection.commitText(composition.text, 1);
            if (inserted && composition.deleteFollowingCodePoint) {
                int followingUtf16Units = Character.charCount(
                    Character.codePointAt(context.followingText, 0));
                if (!deleteFollowingCodePoint(followingUtf16Units)) {
                    pendingDeletionGeneration = destination;
                    pendingDeletionRequest = request;
                    pendingDeletionTranscript = transcript;
                    pendingInsertedText = composition.text;
                    pendingFollowingCodePoint = context.followingText.substring(
                        0, followingUtf16Units);
                    return false;
                }
            }
            return inserted;
        } finally {
            connection.endBatchEdit();
        }
    }

    boolean retryPendingDictationDeletion(long destination, long request) {
        if (!hasPendingDictation(destination, request)) return true;
        if (!pendingDeletionContextStillMatches()) {
            clearPendingDeletion();
            return true;
        }
        if (!deleteFollowingCodePoint(pendingFollowingCodePoint.length())) return false;
        clearPendingDeletion();
        return true;
    }

    private EditorContext readEditorContext() {
        int requestedLength = SURROUNDING_TEXT_LIMIT + 1;
        CharSequence preceding = connection.getTextBeforeCursor(requestedLength, 0);
        CharSequence following = connection.getTextAfterCursor(requestedLength, 0);
        ExtractedText extracted = connection.getExtractedText(new ExtractedTextRequest(), 0);
        int selectionStart = extracted == null
            ? -1
            : extracted.startOffset + extracted.selectionStart;
        boolean precedingTruncated = preceding != null
            && (preceding.length() > SURROUNDING_TEXT_LIMIT
                || (selectionStart >= 0 && selectionStart > preceding.length())
                || (selectionStart < 0 && preceding.length() > 0));
        boolean followingTruncated = following != null && following.length() > SURROUNDING_TEXT_LIMIT;
        String precedingText = preceding == null ? null : preceding.toString();
        String followingText = following == null ? null : following.toString();
        if (precedingText != null && precedingText.length() > SURROUNDING_TEXT_LIMIT) {
            precedingText = precedingText.substring(precedingText.length() - SURROUNDING_TEXT_LIMIT);
        }
        if (followingText != null && followingText.length() > SURROUNDING_TEXT_LIMIT) {
            followingText = followingText.substring(0, SURROUNDING_TEXT_LIMIT);
        }
        if (precedingTruncated && !precedingText.isEmpty()
                && Character.isLowSurrogate(precedingText.charAt(0))) {
            precedingText = precedingText.substring(1);
        }
        if (followingTruncated && !followingText.isEmpty()
                && Character.isHighSurrogate(followingText.charAt(followingText.length() - 1))) {
            followingText = followingText.substring(0, followingText.length() - 1);
        }
        return new EditorContext(
            precedingText,
            precedingTruncated,
            followingText,
            followingTruncated);
    }

    private boolean deleteFollowingCodePoint(int utf16Units) {
        return connection.deleteSurroundingTextInCodePoints(0, 1)
            || connection.deleteSurroundingText(0, utf16Units);
    }

    private boolean pendingDeletionContextStillMatches() {
        CharSequence preceding = connection.getTextBeforeCursor(pendingInsertedText.length(), 0);
        CharSequence following = connection.getTextAfterCursor(pendingFollowingCodePoint.length(), 0);
        return preceding != null
            && pendingInsertedText.contentEquals(preceding)
            && following != null
            && pendingFollowingCodePoint.contentEquals(following);
    }

    boolean hasPendingDictation(long destination, long request) {
        return pendingDeletionGeneration == destination && pendingDeletionRequest == request;
    }

    private void clearPendingDeletion() {
        pendingDeletionGeneration = -1;
        pendingDeletionRequest = -1;
        pendingDeletionTranscript = null;
        pendingInsertedText = null;
        pendingFollowingCodePoint = null;
    }

    boolean deletePreviousCodePoint() {
        clearPendingDeletion();
        if (connection == null) return false;
        CharSequence selected = connection.getSelectedText(0);
        if (selected != null && selected.length() > 0) return connection.commitText("", 1);

        CharSequence preceding = connection.getTextBeforeCursor(2, 0);
        if (preceding != null && preceding.length() == 0) return false;
        return connection.deleteSurroundingTextInCodePoints(1, 0);
    }
}
