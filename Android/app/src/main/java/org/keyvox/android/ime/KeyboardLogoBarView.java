package org.keyvox.android.ime;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffColorFilter;
import android.graphics.RectF;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.animation.LinearInterpolator;
import org.keyvox.android.R;
import org.keyvox.android.dictation.DictationSession;

/** Android-native rendering and animation for the circular KeyVox microphone control. */
final class KeyboardLogoBarView extends View {
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Bitmap microphone;
    private final ValueAnimator animator;
    private final Runnable action;
    private DictationSession.Phase phase = DictationSession.Phase.IDLE;
    private float targetLevel;
    private float displayedLevel;
    private float processingPhase;
    private float lowActivityPhase;
    private long lastFrameNanos;

    KeyboardLogoBarView(Context context, Runnable action) {
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
    }

    void render(DictationSession session) {
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
        invalidate();
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float diameter = Math.min(getWidth(), getHeight());
        float centerX = getWidth() / 2f;
        float centerY = getHeight() / 2f;
        float radius = diameter / 2f - KeyboardStyle.layoutDp(getContext(), 1);

        paint.clearShadowLayer();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(KeyboardStyle.isDark(getContext()) ? Color.BLACK : Color.rgb(229, 229, 244));
        canvas.drawCircle(centerX, centerY, radius, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(KeyboardStyle.layoutDp(getContext(), 2));
        paint.setColor(KeyboardStyle.isDark(getContext()) ? Color.rgb(181, 154, 0) : Color.rgb(199, 155, 0));
        canvas.drawCircle(centerX, centerY, radius - paint.getStrokeWidth() / 2f, paint);

        if (showsBars()) drawBars(canvas, centerX, centerY, diameter);
        else drawMicrophone(canvas, centerX, centerY, diameter);
    }

    private boolean showsBars() {
        return phase == DictationSession.Phase.STARTING
            || phase == DictationSession.Phase.RECORDING
            || phase == DictationSession.Phase.PROCESSING
            || phase == DictationSession.Phase.CANCELLING;
    }

    private void drawMicrophone(Canvas canvas, float centerX, float centerY, float diameter) {
        if (microphone == null) return;
        float side = diameter * 0.65f;
        RectF destination = new RectF(centerX - side / 2, centerY - side / 2, centerX + side / 2, centerY + side / 2);
        paint.setStyle(Paint.Style.FILL);
        paint.setColorFilter(new PorterDuffColorFilter(KeyboardStyle.indigo(getContext()), PorterDuff.Mode.SRC_IN));
        canvas.drawBitmap(microphone, null, destination, paint);
        paint.setColorFilter(null);
    }

    private void drawBars(Canvas canvas, float centerX, float centerY, float diameter) {
        float scale = diameter / KeyboardStyle.layoutDp(getContext(), 52);
        float barWidth = KeyboardStyle.layoutDp(getContext(), 4) * scale;
        float spacing = KeyboardStyle.layoutDp(getContext(), 4) * scale;
        float totalWidth = barWidth * 5 + spacing * 4;
        float startX = centerX - totalWidth / 2;
        float flatHeight = KeyboardStyle.layoutDp(getContext(), 3) * scale;
        float maxHeight = KeyboardStyle.layoutDp(getContext(), 30) * scale;
        float[] emphasis = {0.4f, 0.7f, 1f, 0.7f, 0.4f};

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(KeyboardStyle.indigo(getContext()));
        paint.setShadowLayer(KeyboardStyle.layoutDp(getContext(), 1.5f), 0, 0, KeyboardStyle.active(getContext()));
        for (int index = 0; index < 5; index++) {
            float height;
            if (phase == DictationSession.Phase.PROCESSING || phase == DictationSession.Phase.CANCELLING) {
                float ripple = (float) ((Math.sin(processingPhase + index * 0.8f) + 1) / 2);
                height = flatHeight + ripple * KeyboardStyle.layoutDp(getContext(), 9) * scale;
            } else {
                float quietRipple = (float) ((Math.sin(lowActivityPhase + index * 0.8f) + 1) / 2);
                float ambient = (float) ((Math.sin(lowActivityPhase * 0.9f + index * 1.35f) + 1) / 2);
                float quietLevel = Math.min(displayedLevel / 0.14f, 1);
                float rippleHeight = flatHeight
                    + KeyboardStyle.layoutDp(getContext(), 1.2f) * scale
                    + quietLevel * KeyboardStyle.layoutDp(getContext(), 0.8f) * scale
                    + ambient * KeyboardStyle.layoutDp(getContext(), 0.9f) * scale
                    + quietRipple * KeyboardStyle.layoutDp(getContext(), 2) * scale;
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

    void refreshAppearance() { invalidate(); }

    @Override protected void onDetachedFromWindow() {
        animator.cancel();
        super.onDetachedFromWindow();
    }
}
