package org.keyvox.android.ime;

import android.view.inputmethod.InputConnection;
import android.view.inputmethod.ExtractedText;
import android.view.inputmethod.ExtractedTextRequest;
import java.util.LinkedHashMap;
import java.util.Map;
import org.keyvox.android.dictation.DictationResult;
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
        KeyboardDictationInsertion insertion = commitDictationResult(
            destination,
            request,
            DictationResult.textOnly(text.toString())
        );
        return insertion != null && !hasPendingDictation(destination, request);
    }

    KeyboardDictationInsertion commitDictationResult(
            long destination,
            long request,
            DictationResult result) {
        // A no-speech completion must not erase the editor's current selection.
        if (result.text().length() == 0) {
            return new KeyboardDictationInsertion(
                destination, null, "", null, new LinkedHashMap<>());
        }
        if (destination != generation || connection == null) return null;
        String transcript = result.text();
        if (pendingDeletionGeneration == destination) {
            if (request != pendingDeletionRequest
                    || !transcript.equals(pendingDeletionTranscript)) {
                clearPendingDeletion();
            } else if (!pendingDeletionContextStillMatches()) {
                clearPendingDeletion();
                return null;
            } else if (!deleteFollowingCodePoint(pendingFollowingCodePoint.length())) {
                return null;
            } else {
                clearPendingDeletion();
                return null;
            }
        }

        EditorContext context = readEditorContext();
        NativeEngine.Composition composition = NativeEngine.compose(
            transcript,
            context.precedingText,
            context.precedingTextIsTruncated,
            context.followingText,
            context.followingTextIsTruncated);
        if (composition == null) return null;
        if (composition.text.isEmpty()) {
            return new KeyboardDictationInsertion(
                destination, context.precedingText, "", null, new LinkedHashMap<>());
        }

        Map<DictationResult.FormatState, String> preparedVariants = preparedVariants(
            result,
            context
        );
        DictationResult.FormatState baseState = result.baseState();
        if (baseState != null && !preparedVariants.containsKey(baseState)) {
            baseState = null;
        }
        KeyboardDictationInsertion insertion = new KeyboardDictationInsertion(
            destination,
            context.precedingText,
            composition.text,
            baseState,
            preparedVariants
        );

        connection.beginBatchEdit();
        try {
            boolean inserted = connection.commitText(composition.text, 1);
            if (!inserted) return null;
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
                    return insertion;
                }
            }
            return insertion;
        } finally {
            connection.endBatchEdit();
        }
    }

    boolean currentTextMatchesUntouchedInsertion(KeyboardDictationInsertion insertion) {
        if (insertion == null || insertion.currentText.isEmpty()
                || insertion.editorGeneration != generation || connection == null
                || pendingDeletionGeneration == generation) {
            return false;
        }
        CharSequence selected = connection.getSelectedText(0);
        if (selected != null && selected.length() > 0) return false;

        int requestedLength = insertion.currentText.length() + SURROUNDING_TEXT_LIMIT;
        CharSequence preceding = connection.getTextBeforeCursor(requestedLength, 0);
        if (preceding == null) return false;
        String currentContext = preceding.toString();
        if (!currentContext.endsWith(insertion.currentText)) return false;

        String visiblePrefix = currentContext.substring(
            0,
            currentContext.length() - insertion.currentText.length()
        );
        if (visiblePrefix.isEmpty()) {
            return insertion.documentContextBeforeInput == null
                || insertion.documentContextBeforeInput.isEmpty();
        }
        return insertion.documentContextBeforeInput != null
            && insertion.documentContextBeforeInput.endsWith(visiblePrefix);
    }

    boolean replaceUntouchedInsertion(
            KeyboardDictationInsertion insertion,
            String replacementText) {
        if (!currentTextMatchesUntouchedInsertion(insertion)) return false;
        clearPendingDeletion();
        ExtractedText extracted = connection.getExtractedText(new ExtractedTextRequest(), 0);
        if (extracted == null || extracted.selectionStart != extracted.selectionEnd) return false;
        int cursor = extracted.startOffset + extracted.selectionStart;
        int insertionStart = cursor - insertion.currentText.length();
        if (insertionStart < 0) return false;
        connection.beginBatchEdit();
        try {
            if (!connection.setSelection(insertionStart, cursor)) return false;
            if (connection.commitText(replacementText, 1)) return true;
            connection.setSelection(cursor, cursor);
            return false;
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

    private Map<DictationResult.FormatState, String> preparedVariants(
            DictationResult result,
            EditorContext context) {
        Map<DictationResult.FormatState, String> prepared = new LinkedHashMap<>();
        for (Map.Entry<DictationResult.FormatState, String> variant
                : result.deterministicVariants().entrySet()) {
            NativeEngine.Composition composition = NativeEngine.compose(
                variant.getValue(),
                context.precedingText,
                context.precedingTextIsTruncated,
                null,
                false
            );
            if (composition != null && !composition.text.isEmpty()) {
                prepared.put(variant.getKey(), composition.text);
            }
        }
        return prepared;
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
        if (preceding == null) return connection.deleteSurroundingTextInCodePoints(1, 0);

        int lastIndex = preceding.length() - 1;
        int utf16Units = Character.isLowSurrogate(preceding.charAt(lastIndex))
                && lastIndex > 0
                && Character.isHighSurrogate(preceding.charAt(lastIndex - 1))
            ? 2
            : 1;
        return connection.deleteSurroundingText(utf16Units, 0);
    }
}
