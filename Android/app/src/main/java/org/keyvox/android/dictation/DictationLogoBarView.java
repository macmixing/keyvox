package org.keyvox.android.dictation;

import android.animation.ValueAnimator;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.RectF;
import android.util.TypedValue;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.animation.AccelerateInterpolator;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.Interpolator;
import android.view.animation.LinearInterpolator;
import android.view.animation.OvershootInterpolator;
import org.keyvox.android.R;

/** Canonical Android rendering and animation for the circular KeyVox dictation control. */
public final class DictationLogoBarView extends View {
    private static final float DIAMETER_DP = 53;
    // The mic/bars swap is sequential, not a crossfade: the outgoing element fully
    // shrinks-and-fades away in the first half of TRANSITION_DURATION_MILLIS, then the
    // incoming element pops in during the second half. The two are never both visible.
    private static final long TRANSITION_DURATION_MILLIS = 240;
    private static final float MIC_HIDDEN_SCALE = 0.2f;
    private static final Interpolator OUTGOING_MIC_INTERPOLATOR = new AccelerateInterpolator();
    private static final Interpolator INCOMING_MIC_INTERPOLATOR = new OvershootInterpolator(1.1f);
    private static final Interpolator BARS_FADE_INTERPOLATOR = new DecelerateInterpolator();
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Bitmap microphone;
    private final ValueAnimator animator;
    private final ValueAnimator transitionAnimator = ValueAnimator.ofFloat(0f, 1f);
    private final Runnable action;
    private DictationSession.Phase phase = DictationSession.Phase.IDLE;
    private Boolean showingBars;
    private boolean transitioningToBars;
    private float micAlpha = 1f;
    private float micScale = 1f;
    private float barsAlpha = 0f;
    private float targetLevel;
    private float displayedLevel;
    private float processingPhase;
    private float lowActivityPhase;
    private long lastFrameNanos;

    public DictationLogoBarView(Context context, Runnable action) {
        super(context);
        this.action = action;
        microphone = BitmapFactory.decodeResource(getResources(), R.drawable.microphone_icon);
        setLayerType(LAYER_TYPE_SOFTWARE, null);
        setClickable(true);
        setFocusable(false);
        setContentDescription(getResources().getString(R.string.start_dictation));
        setOnClickListener(view -> {
            performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
            action.run();
        });
        animator = ValueAnimator.ofFloat(0, 1);
        animator.setDuration(1_000);
        animator.setRepeatCount(ValueAnimator.INFINITE);
        animator.setInterpolator(new LinearInterpolator());
        animator.addUpdateListener(value -> {
            updateAnimationState();
            invalidate();
        });
        transitionAnimator.setDuration(TRANSITION_DURATION_MILLIS);
        transitionAnimator.setInterpolator(new LinearInterpolator());
        transitionAnimator.addUpdateListener(value -> {
            applyTransitionFraction((float) value.getAnimatedValue());
            invalidate();
        });
    }

    public static int preferredSizePx(Context context) {
        return dp(context, DIAMETER_DP * layoutScale(context));
    }

    public void render(DictationSession session) {
        phase = session.phase();
        targetLevel = phase == DictationSession.Phase.STARTING || phase == DictationSession.Phase.RECORDING
            ? session.audioLevel()
            : 0;
        boolean animates = phase == DictationSession.Phase.STARTING
            || phase == DictationSession.Phase.RECORDING
            || phase == DictationSession.Phase.PROCESSING
            || phase == DictationSession.Phase.CANCELLING;
        if (animates && !animator.isStarted()) {
            lastFrameNanos = 0;
            animator.start();
        }
        if (!animates && animator.isStarted()) {
            animator.cancel();
            lastFrameNanos = 0;
            targetLevel = 0;
            displayedLevel = 0;
        }

        boolean recording = phase == DictationSession.Phase.STARTING || phase == DictationSession.Phase.RECORDING;
        setContentDescription(getResources().getString(recording ? R.string.stop_dictation : R.string.start_dictation));
        setEnabled(phase != DictationSession.Phase.PROCESSING && phase != DictationSession.Phase.CANCELLING);

        boolean showsBarsNow = showsBars();
        if (showingBars == null) {
            showingBars = showsBarsNow;
            barsAlpha = showsBarsNow ? 1f : 0f;
            micAlpha = showsBarsNow ? 0f : 1f;
            micScale = 1f;
        } else if (showingBars != showsBarsNow) {
            showingBars = showsBarsNow;
            startMicBarsTransition(showsBarsNow);
        }
        invalidate();
    }

    private void startMicBarsTransition(boolean toBars) {
        transitioningToBars = toBars;
        transitionAnimator.cancel();
        transitionAnimator.start();
    }

    /** fraction is 0..1 across the whole swap: [0, 0.5] hides the outgoing element, [0.5, 1] pops in the incoming one. */
    private void applyTransitionFraction(float fraction) {
        boolean outgoingPhase = fraction < 0.5f;
        if (outgoingPhase) {
            float outT = clamp01(fraction / 0.5f);
            if (transitioningToBars) {
                float eased = OUTGOING_MIC_INTERPOLATOR.getInterpolation(outT);
                micAlpha = clamp01(1f - eased);
                micScale = lerp(1f, MIC_HIDDEN_SCALE, eased);
                barsAlpha = 0f;
            } else {
                barsAlpha = 1f - clamp01(BARS_FADE_INTERPOLATOR.getInterpolation(outT));
                micAlpha = 0f;
                micScale = MIC_HIDDEN_SCALE;
            }
        } else {
            float inT = clamp01((fraction - 0.5f) / 0.5f);
            if (transitioningToBars) {
                micAlpha = 0f;
                micScale = MIC_HIDDEN_SCALE;
                barsAlpha = clamp01(BARS_FADE_INTERPOLATOR.getInterpolation(inT));
            } else {
                float eased = INCOMING_MIC_INTERPOLATOR.getInterpolation(inT);
                micAlpha = clamp01(eased);
                micScale = lerp(MIC_HIDDEN_SCALE, 1f, eased);
                barsAlpha = 0f;
            }
        }
    }

    private static float clamp01(float value) {
        return Math.max(0f, Math.min(1f, value));
    }

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int preferred = preferredSizePx(getContext());
        setMeasuredDimension(resolveSize(preferred, widthMeasureSpec), resolveSize(preferred, heightMeasureSpec));
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float diameter = Math.min(getWidth(), getHeight());
        float centerX = getWidth() / 2f;
        float centerY = getHeight() / 2f;
        float radius = diameter / 2f - scaledDp(1);

        paint.clearShadowLayer();
        paint.setAlpha(255);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(isDark() ? Color.BLACK : Color.rgb(229, 229, 244));
        canvas.drawCircle(centerX, centerY, radius, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(scaledDp(2));
        paint.setColor(isDark() ? Color.rgb(181, 154, 0) : Color.rgb(199, 155, 0));
        canvas.drawCircle(centerX, centerY, radius - paint.getStrokeWidth() / 2f, paint);

        if (barsAlpha > 0.001f) drawBars(canvas, centerX, centerY, diameter, barsAlpha);
        if (micAlpha > 0.001f) drawMicrophone(canvas, centerX, centerY, diameter, micAlpha, micScale);
    }

    private boolean showsBars() {
        return phase == DictationSession.Phase.STARTING
            || phase == DictationSession.Phase.RECORDING
            || phase == DictationSession.Phase.PROCESSING
            || phase == DictationSession.Phase.CANCELLING;
    }

    private void drawMicrophone(Canvas canvas, float centerX, float centerY, float diameter, float alpha, float scale) {
        if (microphone == null) return;
        float side = diameter * 0.65f;
        RectF destination = new RectF(centerX - side / 2, centerY - side / 2, centerX + side / 2, centerY + side / 2);
        canvas.save();
        canvas.scale(scale, scale, centerX, centerY);
        paint.setStyle(Paint.Style.FILL);
        paint.setColorFilter(new PorterDuffColorFilter(indigo(), PorterDuff.Mode.SRC_IN));
        paint.setAlpha(Math.round(alpha * 255));
        canvas.drawBitmap(microphone, null, destination, paint);
        paint.setColorFilter(null);
        paint.setAlpha(255);
        canvas.restore();
    }

    private void drawBars(Canvas canvas, float centerX, float centerY, float diameter, float alpha) {
        float scale = diameter / scaledDp(52);
        float barWidth = scaledDp(4) * scale;
        float spacing = scaledDp(4) * scale;
        float totalWidth = barWidth * 5 + spacing * 4;
        float startX = centerX - totalWidth / 2;
        float flatHeight = scaledDp(3) * scale;
        float maxHeight = scaledDp(30) * scale;
        float[] emphasis = {0.4f, 0.7f, 1f, 0.7f, 0.4f};

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(indigo());
        paint.setAlpha(Math.round(alpha * 255));
        paint.setShadowLayer(scaledDp(1.5f), 0, 0, withAlpha(active(), alpha));
        for (int index = 0; index < 5; index++) {
            float height;
            if (phase == DictationSession.Phase.PROCESSING || phase == DictationSession.Phase.CANCELLING) {
                float ripple = (float) ((Math.sin(processingPhase + index * 0.8f) + 1) / 2);
                height = flatHeight + ripple * scaledDp(9) * scale;
            } else {
                float quietRipple = (float) ((Math.sin(lowActivityPhase + index * 0.8f) + 1) / 2);
                float ambient = (float) ((Math.sin(lowActivityPhase * 0.9f + index * 1.35f) + 1) / 2);
                float quietLevel = Math.min(displayedLevel / 0.14f, 1);
                float rippleHeight = flatHeight
                    + scaledDp(1.2f) * scale
                    + quietLevel * scaledDp(0.8f) * scale
                    + ambient * scaledDp(0.9f) * scale
                    + quietRipple * scaledDp(2) * scale;
                float dynamicHeight = displayedLevel * emphasis[index] * maxHeight;
                height = Math.max(rippleHeight, dynamicHeight);
            }
            RectF bar = new RectF(
                startX + index * (barWidth + spacing),
                centerY - height / 2,
                startX + index * (barWidth + spacing) + barWidth,
                centerY + height / 2
            );
            canvas.drawRoundRect(bar, barWidth / 2, barWidth / 2, paint);
        }
        paint.clearShadowLayer();
    }

    private void updateAnimationState() {
        long now = System.nanoTime();
        float seconds = lastFrameNanos == 0 ? 1f / 60f : Math.min((now - lastFrameNanos) / 1_000_000_000f, 0.1f);
        lastFrameNanos = now;
        processingPhase += 6f * seconds;
        lowActivityPhase += 3.6f * seconds;
        float rate = targetLevel > displayedLevel ? 25 : 8;
        displayedLevel += (targetLevel - displayedLevel) * Math.min(rate * seconds, 1);
    }

    public void refreshAppearance() { invalidate(); }

    private boolean isDark() {
        return (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
            == Configuration.UI_MODE_NIGHT_YES;
    }

    private int indigo() {
        return isDark() ? Color.rgb(94, 108, 230) : Color.rgb(88, 86, 214);
    }

    private int active() {
        return isDark() ? Color.rgb(255, 204, 0) : Color.rgb(184, 128, 0);
    }

    private static int withAlpha(int color, float alpha) {
        return Color.argb(Math.round(alpha * 255), Color.red(color), Color.green(color), Color.blue(color));
    }

    private float scaledDp(float value) {
        return dp(getContext(), value * layoutScale(getContext()));
    }

    private static float layoutScale(Context context) {
        float widthDp = context.getResources().getDisplayMetrics().widthPixels
            / context.getResources().getDisplayMetrics().density;
        return Math.min(1, widthDp / 440f);
    }

    private static float lerp(float from, float to, float fraction) {
        return from + (to - from) * fraction;
    }

    private static int dp(Context context, float value) {
        return Math.round(TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            context.getResources().getDisplayMetrics()
        ));
    }

    @Override protected void onDetachedFromWindow() {
        animator.cancel();
        transitionAnimator.cancel();
        super.onDetachedFromWindow();
    }
}
