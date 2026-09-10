package org.keyvox.android.app.navigation;

import android.content.Context;
import android.view.MotionEvent;
import android.widget.FrameLayout;
import java.util.function.Consumer;

/** Recognizes the same directional edge swipes used by the iOS containing app. */
final class SwipeTabContentView extends FrameLayout {
    private static final float EDGE_INSET_DP = 24;
    private static final float MINIMUM_DISTANCE_DP = 20;
    private static final float THRESHOLD_DP = 50;

    private final Consumer<Boolean> previousAttempt;
    private final Consumer<Boolean> nextAttempt;
    private float downX;
    private float downY;
    private boolean beganAtLeadingEdge;
    private boolean beganAtTrailingEdge;

    SwipeTabContentView(
        Context context,
        Consumer<Boolean> previousAttempt,
        Consumer<Boolean> nextAttempt
    ) {
        super(context);
        this.previousAttempt = previousAttempt;
        this.nextAttempt = nextAttempt;
    }

    @Override public boolean onInterceptTouchEvent(MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                downX = event.getX();
                downY = event.getY();
                beganAtLeadingEdge = downX <= dp(EDGE_INSET_DP);
                beganAtTrailingEdge = downX >= getWidth() - dp(EDGE_INSET_DP);
                return false;
            case MotionEvent.ACTION_MOVE:
                if (!beganAtLeadingEdge && !beganAtTrailingEdge) return false;
                float horizontal = event.getX() - downX;
                float vertical = event.getY() - downY;
                return Math.abs(horizontal) >= dp(MINIMUM_DISTANCE_DP)
                    && Math.abs(horizontal) > Math.abs(vertical);
            default:
                return false;
        }
    }

    @Override public boolean onTouchEvent(MotionEvent event) {
        if (event.getActionMasked() == MotionEvent.ACTION_UP) {
            float horizontal = event.getX() - downX;
            float vertical = event.getY() - downY;
            if (Math.abs(horizontal) > Math.abs(vertical)) {
                if (beganAtTrailingEdge && horizontal <= -dp(MINIMUM_DISTANCE_DP)) {
                    nextAttempt.accept(horizontal <= -dp(THRESHOLD_DP));
                } else if (beganAtLeadingEdge && horizontal >= dp(MINIMUM_DISTANCE_DP)) {
                    previousAttempt.accept(horizontal >= dp(THRESHOLD_DP));
                }
            }
            return true;
        }
        return true;
    }

    private float dp(float value) {
        return value * getResources().getDisplayMetrics().density;
    }
}
