package org.keyvox.android.accessibility;

import android.graphics.Rect;
import android.view.accessibility.AccessibilityNodeInfo;

/** Installed checks for accessibility text composition and bubble position persistence. */
public final class AccessibilityInstrumentationChecks {
    private AccessibilityInstrumentationChecks() {}

    public static void run() {
        verifyEmptyEditor();
        verifyVisibleHintIsNotEditorContent();
        verifySelectionReplacement();
        verifyUnicodeSelectionReplacement();
        verifyBubblePosition();
    }

    private static void verifyEmptyEditor() {
        AccessibilityTextEdit edit = edit("", 0, 0, "Ready.");
        check(edit != null && edit.text.equals("Ready.") && edit.cursor == 6);
    }

    private static void verifyVisibleHintIsNotEditorContent() {
        AccessibilityNodeInfo node = AccessibilityNodeInfo.obtain();
        node.setText("Placeholder");
        node.setHintText("Placeholder");
        node.setShowingHintText(true);
        node.setTextSelection(-1, -1);
        AccessibilityTextEdit edit = AccessibilityTextEdit.create(node, "Ready.");
        check(edit != null && edit.text.equals("Ready.") && edit.cursor == 6);
    }

    private static void verifySelectionReplacement() {
        AccessibilityTextEdit edit = edit("left middle right", 5, 11, "Replacement.");
        check(edit != null && edit.text.equals("left replacement right"));
        check(edit.cursor == "left replacement".length());
    }

    private static void verifyUnicodeSelectionReplacement() {
        AccessibilityTextEdit edit = edit("left 🙂 right", 5, 7, "Center.");
        check(edit != null && edit.text.equals("left center right"));
        check(edit.cursor == "left center".length());
    }

    private static void verifyBubblePosition() {
        Rect area = new Rect(20, 40, 920, 1_840);
        int x = BubblePosition.coordinate(area.left, area.width(), 0.25f);
        int y = BubblePosition.coordinate(area.top, area.height(), 0.75f);
        check(x == 245 && y == 1_390);
        check(BubblePosition.fraction(x, area.left, area.width()) == 0.25f);
        check(BubblePosition.fraction(y, area.top, area.height()) == 0.75f);
        check(BubblePosition.clampX(-1, area) == area.left);
        check(BubblePosition.clampY(2_000, area) == area.bottom);
    }

    private static AccessibilityTextEdit edit(
            String text,
            int selectionStart,
            int selectionEnd,
            String transcript) {
        AccessibilityNodeInfo node = AccessibilityNodeInfo.obtain();
        node.setText(text);
        node.setTextSelection(selectionStart, selectionEnd);
        return AccessibilityTextEdit.create(node, transcript);
    }

    private static void check(boolean condition) {
        if (!condition) throw new AssertionError("Accessibility dictation invariant failed");
    }
}
