package org.keyvox.android.ime;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import java.util.ArrayList;
import java.util.List;

/** Lays out one key row with deterministic pixel rounding. */
final class KeyboardKeyRowView extends ViewGroup {
    private final List<Float> widths = new ArrayList<>();

    KeyboardKeyRowView(Context context) {
        super(context);
        setClipChildren(false);
    }

    void addKey(View key, float widthUnits) {
        widths.add(widthUnits);
        addView(key);
    }

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = MeasureSpec.getSize(widthMeasureSpec);
        int height = MeasureSpec.getSize(heightMeasureSpec);
        for (int index = 0; index < getChildCount(); index++) {
            int childWidth = rightEdge(width, index) - leftEdge(width, index);
            getChildAt(index).measure(
                MeasureSpec.makeMeasureSpec(childWidth, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
            );
        }
        setMeasuredDimension(width, height);
    }

    @Override protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        int width = right - left;
        int height = bottom - top;
        for (int index = 0; index < getChildCount(); index++) {
            getChildAt(index).layout(leftEdge(width, index), 0, rightEdge(width, index), height);
        }
    }

    private int leftEdge(int width, int index) {
        if (isTenColumnRow()) return KeyboardStyle.tenColumnLeft(getContext(), width, index);
        int spacing = KeyboardStyle.layoutDp(getContext(), KeyboardStyle.KEY_SPACING_DP);
        int available = width - spacing * Math.max(getChildCount() - 1, 0);
        return index * spacing + Math.round(available * unitsBefore(index) / totalUnits());
    }

    private int rightEdge(int width, int index) {
        if (isTenColumnRow()) return KeyboardStyle.tenColumnRight(getContext(), width, index);
        int spacing = KeyboardStyle.layoutDp(getContext(), KeyboardStyle.KEY_SPACING_DP);
        int available = width - spacing * Math.max(getChildCount() - 1, 0);
        return index * spacing + Math.round(available * unitsBefore(index + 1) / totalUnits());
    }

    private float unitsBefore(int endIndex) {
        float result = 0;
        for (int index = 0; index < endIndex; index++) result += widths.get(index);
        return result;
    }

    private float totalUnits() {
        float result = 0;
        for (float width : widths) result += width;
        return result;
    }

    private boolean isTenColumnRow() {
        if (widths.size() != 10) return false;
        for (float width : widths) if (width != 1) return false;
        return true;
    }
}
