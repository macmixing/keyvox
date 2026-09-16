package org.keyvox.android.accessibility;

import android.animation.ValueAnimator;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import org.keyvox.android.R;
import org.keyvox.android.dictation.DictationLogoBarView;

/** Renders and animates the floating bubble's compact cancel orb. */
final class DictationBubbleCancelView extends View {
    private static final float TOUCH_SIZE_RATIO = 0.62f;
    private static final long ENTER_DURATION_MILLIS = 260;
    private static final long EXIT_DURATION_MILLIS = 170;
    private static final float HIDDEN_SCALE = 0.2f;
    private static final float ENTER_ROTATION_DEGREES = -130f;
    private static final float EXIT_ROTATION_DEGREES = 90f;
    private static final long PULSE_DURATION_MILLIS = 1_400;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final ValueAnimator pulse;
    private float pulseFraction;

    DictationBubbleCancelView(Context context, Runnable cancel) {
        super(context);
        setLayerType(LAYER_TYPE_SOFTWARE, null);
        setClickable(true);
        setFocusable(false);
        setContentDescription(context.getString(R.string.cancel_dictation));
        setOnClickListener(ignored -> {
            performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
            cancel.run();
        });
        pulse = ValueAnimator.ofFloat(0, 1);
        pulse.setDuration(PULSE_DURATION_MILLIS);
        pulse.setRepeatCount(ValueAnimator.INFINITE);
        pulse.setRepeatMode(ValueAnimator.REVERSE);
        pulse.setInterpolator(new AccelerateDecelerateInterpolator());
        pulse.addUpdateListener(value -> {
            pulseFraction = (float) value.getAnimatedValue();
            invalidate();
        });
    }

    static int preferredSizePx(Context context) {
        return Math.round(DictationLogoBarView.preferredSizePx(context) * TOUCH_SIZE_RATIO);
    }

    void animateIn() {
        animate().cancel();
        setAlpha(0f);
        setScaleX(HIDDEN_SCALE);
        setScaleY(HIDDEN_SCALE);
        setRotation(ENTER_ROTATION_DEGREES);
        animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .rotation(0f)
            .setDuration(ENTER_DURATION_MILLIS)
            .setInterpolator(new OvershootInterpolator(1.6f))
            .withEndAction(null)
            .start();
        if (!pulse.isStarted()) pulse.start();
    }

    void animateOut(Runnable completion) {
        animate().cancel();
        animate()
            .alpha(0f)
            .scaleX(HIDDEN_SCALE)
            .scaleY(HIDDEN_SCALE)
            .rotation(EXIT_ROTATION_DEGREES)
            .setDuration(EXIT_DURATION_MILLIS)
            .setInterpolator(new AccelerateDecelerateInterpolator())
            .withEndAction(() -> {
                pulse.cancel();
                if (completion != null) completion.run();
            })
            .start();
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float diameter = Math.min(getWidth(), getHeight());
        float centerX = getWidth() / 2f;
        float centerY = getHeight() / 2f;
        float radius = diameter / 2f - scaledStroke() * 1.5f;
        float breath = 0.05f * pulseFraction;

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(isDark() ? Color.BLACK : Color.rgb(229, 229, 244));
        canvas.drawCircle(centerX, centerY, radius, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(scaledStroke());
        paint.setColor(ring());
        canvas.drawCircle(centerX, centerY, radius - paint.getStrokeWidth() / 2f, paint);

        float halfSide = diameter * (0.16f + breath * 0.6f);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeWidth(diameter * 0.09f);
        paint.setColor(mark());
        canvas.drawLine(centerX - halfSide, centerY - halfSide, centerX + halfSide, centerY + halfSide, paint);
        canvas.drawLine(centerX + halfSide, centerY - halfSide, centerX - halfSide, centerY + halfSide, paint);
    }

    @Override protected void onDetachedFromWindow() {
        pulse.cancel();
        super.onDetachedFromWindow();
    }

    private boolean isDark() {
        return (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
            == Configuration.UI_MODE_NIGHT_YES;
    }

    private int ring() {
        return isDark() ? Color.rgb(163, 38, 30) : Color.rgb(122, 24, 18);
    }

    private int mark() {
        return isDark() ? Color.rgb(255, 108, 96) : Color.rgb(196, 34, 26);
    }

    private float scaledStroke() {
        return Math.min(getWidth(), getHeight()) * 0.045f;
    }
}
