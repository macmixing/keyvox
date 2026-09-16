package org.keyvox.android.accessibility;

import android.graphics.Rect;

/** Converts the bubble's persisted normalized position to and from current screen bounds. */
final class BubblePosition {
    private BubblePosition() {}

    static int coordinate(int minimum, int length, float fraction) {
        return Math.round(minimum + clampFraction(fraction) * length);
    }

    static float fraction(int coordinate, int minimum, int length) {
        return length == 0 ? 0 : clampFraction((coordinate - minimum) / (float) length);
    }

    static int clampX(int x, Rect area) {
        return Math.max(area.left, Math.min(x, area.right));
    }

    static int clampY(int y, Rect area) {
        return Math.max(area.top, Math.min(y, area.bottom));
    }

    private static float clampFraction(float value) {
        return Math.max(0, Math.min(value, 1));
    }
}
