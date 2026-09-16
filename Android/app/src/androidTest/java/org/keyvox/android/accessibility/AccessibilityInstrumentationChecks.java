package org.keyvox.android.accessibility;

import android.graphics.Rect;
import android.graphics.PointF;
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
        verifyBubbleFlingPhysics();
        verifyBubbleDragVelocity();
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
        Rect movementArea = BubblePosition.movementArea(1_000, 2_000, 20, 100, 30, 40, 100, 100);
        check(movementArea.equals(new Rect(0, 0, 850, 1_760)));

        Rect area = new Rect(20, 40, 920, 1_840);
        int x = BubblePosition.coordinate(area.left, area.width(), 0.25f);
        int y = BubblePosition.coordinate(area.top, area.height(), 0.75f);
        check(x == 245 && y == 1_390);
        check(BubblePosition.fraction(x, area.left, area.width()) == 0.25f);
        check(BubblePosition.fraction(y, area.top, area.height()) == 0.75f);
        check(BubblePosition.clampX(-1, area) == area.left);
        check(BubblePosition.clampY(2_000, area) == area.bottom);
    }

    private static void verifyBubbleFlingPhysics() {
        Rect bounds = new Rect(0, 0, 100, 100);
        BubbleFlingPhysics.Impact right = BubbleFlingPhysics.firstImpact(20, 25, 200, 10, bounds);
        check(right != null && right.edge == BubbleFlingPhysics.Edge.RIGHT && right.position.x == 100);

        BubbleFlingPhysics.Impact left = BubbleFlingPhysics.firstImpact(80, 25, -200, 10, bounds);
        check(left != null && left.edge == BubbleFlingPhysics.Edge.LEFT && left.position.x == 0);

        BubbleFlingPhysics.Impact top = BubbleFlingPhysics.firstImpact(40, 80, 8, -220, bounds);
        check(top != null && top.edge == BubbleFlingPhysics.Edge.TOP && top.position.y == 0);

        BubbleFlingPhysics.Impact bottom = BubbleFlingPhysics.firstImpact(40, 20, 8, 220, bounds);
        check(bottom != null && bottom.edge == BubbleFlingPhysics.Edge.BOTTOM && bottom.position.y == 100);

        BubbleFlingPhysics.Impact diagonal = BubbleFlingPhysics.firstImpact(50, 50, -100, -200, bounds);
        check(diagonal != null && diagonal.edge == BubbleFlingPhysics.Edge.TOP);

        check(BubbleFlingPhysics.firstImpact(50, 50, 0.00001f, -0.00001f, bounds) == null);

        PointF reflected = BubbleFlingPhysics.reflectedDirection(2, 1, BubbleFlingPhysics.Edge.RIGHT.normal);
        check(Math.abs(reflected.x + 0.8944272f) < 0.0001f);
        check(Math.abs(reflected.y - 0.4472136f) < 0.0001f);

        check(BubbleFlingPhysics.travelDurationMillis(100, 10_000, 120, 300) == 120);
        check(BubbleFlingPhysics.travelDurationMillis(100, 10, 120, 300) == 300);
    }

    private static void verifyBubbleDragVelocity() {
        BubbleDragVelocity velocity = new BubbleDragVelocity();
        velocity.begin(0, 0, 1_000);
        velocity.append(20, 0, 1_100);
        velocity.append(80, 0, 1_160);
        PointF result = velocity.releaseVelocity();
        check(result != null && Math.abs(result.x - 1_000) < 0.001f && result.y == 0);
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
