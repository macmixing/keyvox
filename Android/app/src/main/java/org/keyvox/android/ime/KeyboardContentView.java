package org.keyvox.android.ime;

import android.content.Context;
import android.widget.LinearLayout;

/** Keeps keyboard controls comfortably proportioned on tablets and unfolded devices. */
final class KeyboardContentView extends LinearLayout {
    KeyboardContentView(Context context) {
        super(context);
        setOrientation(VERTICAL);
        setClipChildren(false);
        setClipToPadding(false);
    }

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int availableWidth = MeasureSpec.getSize(widthMeasureSpec);
        int maximumWidth = KeyboardStyle.dp(getContext(), KeyboardStyle.MAX_CONTENT_WIDTH_DP);
        int contentWidth = Math.min(availableWidth, maximumWidth);
        super.onMeasure(
            MeasureSpec.makeMeasureSpec(contentWidth, MeasureSpec.EXACTLY),
            heightMeasureSpec
        );
    }
}
