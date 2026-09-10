package org.keyvox.android.app.dictionary;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.FrameLayout;
import org.keyvox.android.R;

/** Animated lower-right add control for the dictionary screen. */
final class DictionaryFloatingAddButton extends FrameLayout {
    static final float DIAMETER_DP = 53.5f;
    private static final float ARTWORK_SCALE = DIAMETER_DP / 52.2f;
    private final Paint fillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint strokePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint plusPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    DictionaryFloatingAddButton(Context context, Runnable action) {
        super(context);
        setContentDescription(context.getString(R.string.dictionary_add_accessibility));
        setElevation(dp(12));

        setWillNotDraw(false);
        fillPaint.setColor(0xCC000000);
        strokePaint.setStyle(Paint.Style.STROKE);
        strokePaint.setStrokeWidth(dp(2 * ARTWORK_SCALE));
        strokePaint.setColor(getResources().getColor(R.color.app_primary_action, context.getTheme()));
        plusPaint.setStyle(Paint.Style.STROKE);
        plusPaint.setStrokeWidth(dp(4 * ARTWORK_SCALE));
        plusPaint.setStrokeCap(Paint.Cap.ROUND);
        plusPaint.setColor(getResources().getColor(R.color.app_accent, context.getTheme()));
        setOnClickListener(view -> {
            performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK);
            action.run();
        });
        setOnTouchListener((view, event) -> {
            switch (event.getActionMasked()) {
                case android.view.MotionEvent.ACTION_DOWN:
                    animate()
                        .scaleX(0.88f)
                        .scaleY(0.88f)
                        .alpha(0.72f)
                        .setDuration(160)
                        .setInterpolator(new AccelerateDecelerateInterpolator())
                        .start();
                    break;
                case android.view.MotionEvent.ACTION_UP:
                case android.view.MotionEvent.ACTION_CANCEL:
                    animate()
                        .scaleX(1)
                        .scaleY(1)
                        .alpha(1)
                        .setDuration(160)
                        .setInterpolator(new AccelerateDecelerateInterpolator())
                        .start();
                    break;
                default:
                    break;
            }
            return false;
        });
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float inset = dp(ARTWORK_SCALE);
        RectF circle = new RectF(inset, inset, getWidth() - inset, getHeight() - inset);
        canvas.drawOval(circle, fillPaint);
        canvas.drawOval(circle, strokePaint);
        float centerX = getWidth() / 2f;
        float centerY = getHeight() / 2f;
        float halfLength = dp(9.2f * ARTWORK_SCALE);
        canvas.drawLine(centerX - halfLength, centerY, centerX + halfLength, centerY, plusPaint);
        canvas.drawLine(centerX, centerY - halfLength, centerX, centerY + halfLength, plusPaint);
    }

    void present() {
        setVisibility(VISIBLE);
        setScaleX(0.82f);
        setScaleY(0.82f);
        setAlpha(0);
        postDelayed(() -> animate()
            .scaleX(1)
            .scaleY(1)
            .alpha(1)
            .setDuration(260)
            .setInterpolator(new OvershootInterpolator(0.65f))
            .start(), 100);
    }

    void hideImmediately() {
        animate().cancel();
        setVisibility(INVISIBLE);
    }

    private int dp(float value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
