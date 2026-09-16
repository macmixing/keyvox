package org.keyvox.android.accessibility;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.accessibility.AccessibilityNodeInfo;
import java.util.function.Consumer;
import org.keyvox.android.engine.NativeEngine;

/** Performs and verifies one text replacement against the editor captured at dictation start. */
final class AccessibilityTextInsertion {
    private static final int VERIFICATION_ATTEMPTS = 6;
    private static final long VERIFICATION_DELAY_MS = 50;
    private final AccessibilityEditorLocator locator;
    private final DictationClipboard clipboard;
    private final Handler main = new Handler(Looper.getMainLooper());

    AccessibilityTextInsertion(
            AccessibilityEditorLocator locator,
            DictationClipboard clipboard) {
        this.locator = locator;
        this.clipboard = clipboard;
    }

    void insert(
            AccessibilityEditorTarget target,
            String transcript,
            Consumer<Boolean> completion) {
        AccessibilityNodeInfo node = locator.currentEditor(target);
        if (node == null) {
            completion.accept(false);
            return;
        }
        if ((node.getActions() & AccessibilityNodeInfo.ACTION_SET_TEXT) == 0) {
            paste(node, target, transcript, completion);
            return;
        }
        AccessibilityTextEdit edit = AccessibilityTextEdit.create(node, transcript);
        if (edit == null) {
            completion.accept(false);
            return;
        }

        Bundle textArguments = new Bundle();
        textArguments.putCharSequence(
            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
            edit.text
        );
        if (!node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, textArguments)) {
            completion.accept(false);
            return;
        }

        Bundle selectionArguments = new Bundle();
        selectionArguments.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, edit.cursor);
        selectionArguments.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, edit.cursor);
        node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, selectionArguments);
        verifySetText(node, target, edit.text, 0, completion);
    }

    private void paste(
            AccessibilityNodeInfo node,
            AccessibilityEditorTarget target,
            String transcript,
            Consumer<Boolean> completion) {
        NativeEngine.Composition composition = NativeEngine.compose(
            transcript,
            null,
            false,
            null,
            false
        );
        String pasteText = composition == null ? transcript : composition.text;
        if (pasteText.isEmpty()) {
            completion.accept(false);
            return;
        }
        CharSequence current = node.isShowingHintText() ? null : node.getText();
        String before = current == null ? "" : current.toString();
        clipboard.placeForPaste(pasteText);
        if (!node.performAction(AccessibilityNodeInfo.ACTION_PASTE)) {
            completion.accept(false);
            return;
        }
        verifyPaste(node, target, before, pasteText, 0, completion);
    }

    private void verifySetText(
            AccessibilityNodeInfo writtenNode,
            AccessibilityEditorTarget target,
            String expectedText,
            int attempt,
            Consumer<Boolean> completion) {
        main.postDelayed(() -> {
            AccessibilityNodeInfo current = writtenNode.refresh()
                ? writtenNode
                : locator.currentEditorInWindow(target);
            CharSequence actual = current == null ? null : current.getText();
            if (actual != null && expectedText.contentEquals(actual)) {
                completion.accept(true);
            } else if (attempt + 1 < VERIFICATION_ATTEMPTS) {
                verifySetText(writtenNode, target, expectedText, attempt + 1, completion);
            } else {
                completion.accept(false);
            }
        }, VERIFICATION_DELAY_MS);
    }

    private void verifyPaste(
            AccessibilityNodeInfo writtenNode,
            AccessibilityEditorTarget target,
            String before,
            String pastedText,
            int attempt,
            Consumer<Boolean> completion) {
        main.postDelayed(() -> {
            AccessibilityNodeInfo current = writtenNode.refresh()
                ? writtenNode
                : locator.currentEditorInWindow(target);
            CharSequence value = current == null || current.isShowingHintText()
                ? null
                : current.getText();
            String after = value == null ? "" : value.toString();
            if (!after.equals(before) && after.contains(pastedText)) {
                completion.accept(true);
            } else if (attempt + 1 < VERIFICATION_ATTEMPTS) {
                verifyPaste(writtenNode, target, before, pastedText, attempt + 1, completion);
            } else {
                completion.accept(false);
            }
        }, VERIFICATION_DELAY_MS);
    }
}
