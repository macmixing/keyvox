package org.keyvox.android.app.presentation;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.HapticFeedbackConstants;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.widget.CompoundButton;
import org.keyvox.android.R;

/** Shared iOS-sized toggle used by containing-app settings rows. */
public final class AppToggleView extends CompoundButton {
    private static final float TRACK_WIDTH_DP = 44;
    private static final float TRACK_HEIGHT_DP = 26;
    private static final float THUMB_DIAMETER_DP = 22;
    private static final long ANIMATION_DURATION_MS = 220;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private ValueAnimator thumbAnimator;
    private float thumbPosition;

    public AppToggleView(Context context) {
        super(context);
        setButtonDrawable(null);
        setClickable(true);
        setFocusable(true);
        setMinimumWidth(dp(TRACK_WIDTH_DP));
        setMinimumHeight(dp(TRACK_HEIGHT_DP));
        thumbPosition = isChecked() ? 1f : 0f;
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        setMeasuredDimension(
            resolveSize(dp(TRACK_WIDTH_DP), widthMeasureSpec),
            resolveSize(dp(TRACK_HEIGHT_DP), heightMeasureSpec)
        );
    }

    @Override
    protected void onDraw(Canvas canvas) {
        float width = dp(TRACK_WIDTH_DP);
        float height = dp(TRACK_HEIGHT_DP);
        float left = (getWidth() - width) / 2f;
        float top = (getHeight() - height) / 2f;

        paint.setColor(color(isChecked() ? R.color.app_accent : R.color.app_tab_unselected));
        canvas.drawRoundRect(left, top, left + width, top + height, height / 2f, height / 2f, paint);

        float thumbRadius = dp(THUMB_DIAMETER_DP) / 2f;
        float inset = (height - (thumbRadius * 2f)) / 2f;
        float startCenter = left + inset + thumbRadius;
        float endCenter = left + width - inset - thumbRadius;
        float centerX = startCenter + ((endCenter - startCenter) * thumbPosition);

        paint.setColor(color(R.color.app_primary_text));
        canvas.drawCircle(centerX, top + (height / 2f), thumbRadius, paint);
    }

    @Override
    public void setChecked(boolean checked) {
        boolean changed = checked != isChecked();
        super.setChecked(checked);
        if (!changed) return;

        float target = checked ? 1f : 0f;
        if (!isLaidOut()) {
            thumbPosition = target;
            invalidate();
            return;
        }

        if (thumbAnimator != null) thumbAnimator.cancel();
        thumbAnimator = ValueAnimator.ofFloat(thumbPosition, target);
        thumbAnimator.setDuration(ANIMATION_DURATION_MS);
        thumbAnimator.setInterpolator(new AccelerateDecelerateInterpolator());
        thumbAnimator.addUpdateListener(animation -> {
            thumbPosition = (float) animation.getAnimatedValue();
            invalidate();
        });
        thumbAnimator.start();
    }

    @Override
    public CharSequence getAccessibilityClassName() {
        return android.widget.Switch.class.getName();
    }

    @Override
    public boolean performClick() {
        int feedback = isChecked()
            ? HapticFeedbackConstants.TOGGLE_OFF
            : HapticFeedbackConstants.TOGGLE_ON;
        if (!performHapticFeedback(feedback)) {
            performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
        }
        return super.performClick();
    }

    private int color(int id) {
        return getResources().getColor(id, getContext().getTheme());
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
