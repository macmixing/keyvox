package org.keyvox.android.app.presentation;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Shader;
import android.view.View;
import android.view.animation.LinearInterpolator;
import org.keyvox.android.R;

/** Draws and animates the containing app's compact KeyVox brand mark. */
public final class AppLogoView extends View {
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private ValueAnimator rippleAnimator;
    private float ripplePhase;

    public AppLogoView(Context context) {
        super(context);
        setLayerType(LAYER_TYPE_SOFTWARE, null);
    }

    @Override protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        updateRippleAnimation();
    }

    @Override public void onVisibilityAggregated(boolean isVisible) {
        super.onVisibilityAggregated(isVisible);
        if (isVisible) {
            startRippleAnimation();
        } else {
            stopRippleAnimation();
        }
    }

    @Override protected void onDetachedFromWindow() {
        stopRippleAnimation();
        super.onDetachedFromWindow();
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float size = Math.min(getWidth(), getHeight()) * (32f / 44f);
        float scale = size / 44f;
        float centerX = getWidth() / 2f;
        float centerY = getHeight() / 2f;
        float radius = size / 2f;

        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Color.argb(209, 0, 0, 0));
        paint.setShadowLayer(6f * scale, 0, 0, Color.argb(77, 0, 0, 0));
        canvas.drawCircle(centerX, centerY, radius, paint);

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(2f * scale);
        paint.setColor(Color.argb(115, 255, 214, 10));
        paint.setShadowLayer(6f * scale, 0, 0, Color.argb(89, 255, 214, 10));
        canvas.drawCircle(centerX, centerY, radius, paint);

        paint.clearShadowLayer();
        paint.setColor(Color.argb(153, 255, 214, 10));
        canvas.drawCircle(centerX, centerY, radius, paint);

        paint.setStyle(Paint.Style.FILL);
        paint.setAlpha(255);
        paint.setShadowLayer(2.2f * scale, 0, 0, Color.argb(191, 255, 214, 10));
        float barWidth = 3.5f * scale;
        float gap = 3f * scale;
        float totalWidth = 5 * barWidth + 4 * gap;
        float left = centerX - totalWidth / 2f;
        int indigo = getResources().getColor(R.color.app_accent, getContext().getTheme());
        int luminousIndigo = Color.rgb(113, 111, 240);
        for (int index = 0; index < 5; index++) {
            float waveOffset = ripplePhase + index * 0.8f;
            float rippleHeight = (float) (Math.sin(waveOffset) * 0.5 + 0.5);
            float height = (8f + rippleHeight * 10f) * scale;
            float barLeft = left + index * (barWidth + gap);
            paint.setShader(new LinearGradient(
                barLeft,
                centerY + height / 2f,
                barLeft,
                centerY - height / 2f,
                indigo,
                luminousIndigo,
                Shader.TileMode.CLAMP
            ));
            canvas.drawRoundRect(barLeft, centerY - height / 2f, barLeft + barWidth, centerY + height / 2f,
                2f * scale, 2f * scale, paint);
        }
        paint.setShader(null);
    }

    private void startRippleAnimation() {
        if (rippleAnimator != null) return;
        rippleAnimator = ValueAnimator.ofFloat(0f, (float) (Math.PI * 2));
        rippleAnimator.setDuration(1_005);
        rippleAnimator.setRepeatCount(ValueAnimator.INFINITE);
        rippleAnimator.setInterpolator(new LinearInterpolator());
        rippleAnimator.addUpdateListener(animation -> {
            ripplePhase = (float) animation.getAnimatedValue();
            invalidate();
        });
        rippleAnimator.start();
    }

    private void updateRippleAnimation() {
        if (isAttachedToWindow() && isShown() && getWindowVisibility() == VISIBLE) {
            startRippleAnimation();
        } else {
            stopRippleAnimation();
        }
    }

    private void stopRippleAnimation() {
        if (rippleAnimator == null) return;
        rippleAnimator.cancel();
        rippleAnimator = null;
    }
}
