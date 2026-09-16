package org.keyvox.android.accessibility;

import android.animation.ValueAnimator;
import android.graphics.PointF;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;
import android.view.animation.AccelerateDecelerateInterpolator;

/** Runs the bubble's fling flight, edge overshoot, and settle motion. */
final class BubbleMotionController {
    interface PositionUpdater {
        void update(int x, int y);
    }

    private static final float FLING_MINIMUM_SPEED_DP = 1_000;
    private static final float FLING_MINIMUM_TRAVEL_DISTANCE_DP = 36;
    private static final float OVERSHOOT_MINIMUM_DISTANCE_DP = 6;
    private static final long FLING_TRAVEL_DURATION_MIN_MILLIS = 120;
    private static final long FLING_TRAVEL_DURATION_MAX_MILLIS = 300;
    private static final long SETTLE_START_DELAY_MILLIS = 50;
    private static final long OVERSHOOT_DURATION_MILLIS = SETTLE_START_DELAY_MILLIS;
    private static final long SETTLE_DURATION_MILLIS = 100;

    private final Handler main = new Handler(Looper.getMainLooper());
    private final PositionUpdater positionUpdater;
    private final float density;
    private ValueAnimator animator;
    private Runnable pendingSettle;
    private float currentX;
    private float currentY;

    BubbleMotionController(float density, PositionUpdater positionUpdater) {
        this.density = density;
        this.positionUpdater = positionUpdater;
    }

    boolean fling(
            int currentX,
            int currentY,
            float velocityX,
            float velocityY,
            Rect bounds,
            Runnable completion) {
        float speed = (float) Math.hypot(velocityX, velocityY);
        if (speed < FLING_MINIMUM_SPEED_DP * density) return false;

        BubbleFlingPhysics.Impact impact = BubbleFlingPhysics.firstImpact(
            currentX,
            currentY,
            velocityX,
            velocityY,
            bounds
        );
        if (impact == null) return false;

        float distance = (float) Math.hypot(impact.position.x - currentX, impact.position.y - currentY);
        if (distance < FLING_MINIMUM_TRAVEL_DISTANCE_DP * density) return false;

        cancel();
        this.currentX = currentX;
        this.currentY = currentY;
        long duration = BubbleFlingPhysics.travelDurationMillis(
            distance,
            speed,
            FLING_TRAVEL_DURATION_MIN_MILLIS,
            FLING_TRAVEL_DURATION_MAX_MILLIS
        );
        PointF bounceDirection = BubbleFlingPhysics.reflectedDirection(
            velocityX,
            velocityY,
            impact.edge.normal
        );
        animate(
            currentX,
            currentY,
            impact.position.x,
            impact.position.y,
            duration,
            progress -> 1 - (float) Math.pow(1 - progress, 3),
            () -> bounce(impact.position, bounceDirection, completion)
        );
        return true;
    }

    void cancel() {
        if (animator != null) animator.cancel();
        animator = null;
        if (pendingSettle != null) main.removeCallbacks(pendingSettle);
        pendingSettle = null;
    }

    private void bounce(PointF target, PointF direction, Runnable completion) {
        float overshootDistance = OVERSHOOT_MINIMUM_DISTANCE_DP * density;
        float overshootX = target.x + direction.x * overshootDistance;
        float overshootY = target.y + direction.y * overshootDistance;
        animate(
            target.x,
            target.y,
            overshootX,
            overshootY,
            OVERSHOOT_DURATION_MILLIS,
            new AccelerateDecelerateInterpolator()::getInterpolation,
            null
        );
        pendingSettle = () -> {
            pendingSettle = null;
            if (animator != null) animator.cancel();
            animate(
                currentX,
                currentY,
                target.x,
                target.y,
                SETTLE_DURATION_MILLIS,
                new AccelerateDecelerateInterpolator()::getInterpolation,
                completion
            );
        };
        main.postDelayed(pendingSettle, SETTLE_START_DELAY_MILLIS);
    }

    private void animate(
            float startX,
            float startY,
            float endX,
            float endY,
            long durationMillis,
            android.animation.TimeInterpolator interpolator,
            Runnable completion) {
        ValueAnimator next = ValueAnimator.ofFloat(0, 1);
        animator = next;
        next.setDuration(durationMillis);
        next.setInterpolator(interpolator);
        next.addUpdateListener(value -> {
            float progress = (float) value.getAnimatedValue();
            currentX = startX + (endX - startX) * progress;
            currentY = startY + (endY - startY) * progress;
            positionUpdater.update(Math.round(currentX), Math.round(currentY));
        });
        next.addListener(new android.animation.AnimatorListenerAdapter() {
            private boolean cancelled;

            @Override public void onAnimationCancel(android.animation.Animator animation) {
                cancelled = true;
            }

            @Override public void onAnimationEnd(android.animation.Animator animation) {
                if (animator != next) return;
                animator = null;
                if (!cancelled && completion != null) completion.run();
            }
        });
        next.start();
    }
}
