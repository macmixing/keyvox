package org.keyvox.android.app.presentation;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ScrollView;

/** Scroll container with the app-owned tinted indicator used by scrollable text surfaces. */
public final class AppTintedScrollView extends FrameLayout {
    private static final float INDICATOR_OPACITY = 0.92f;
    private static final int INDICATOR_WIDTH_DP = 3;
    private static final int MINIMUM_THUMB_HEIGHT_DP = 24;
    private static final int TRAILING_TOUCH_CLEARANCE_DP = 12;
    private static final int OVERFLOW_THRESHOLD_DP = 1;

    private final int maximumHeight;
    private final int indicatorWidth;
    private final int minimumThumbHeight;
    private final int overflowThreshold;
    private final TouchCoordinatingScrollView scrollView;
    private final IndicatorView indicator;
    private final Paint indicatorPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    public AppTintedScrollView(
        Context context,
        int contentPadding,
        int minimumHeight,
        int maximumHeight,
        int indicatorTint
    ) {
        super(context);
        this.maximumHeight = maximumHeight;
        indicatorWidth = dp(INDICATOR_WIDTH_DP);
        minimumThumbHeight = dp(MINIMUM_THUMB_HEIGHT_DP);
        overflowThreshold = dp(OVERFLOW_THRESHOLD_DP);

        indicatorPaint.setColor(indicatorTint);
        indicatorPaint.setAlpha(Math.round(255 * INDICATOR_OPACITY));
        setMinimumHeight(minimumHeight);

        scrollView = new TouchCoordinatingScrollView(context);
        scrollView.setFillViewport(true);
        scrollView.setPadding(contentPadding, contentPadding, contentPadding, contentPadding);
        scrollView.setVerticalScrollBarEnabled(false);
        super.addView(scrollView, new LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        indicator = new IndicatorView(context);
        indicator.setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
        LayoutParams indicatorParams = new LayoutParams(
            dp(TRAILING_TOUCH_CLEARANCE_DP),
            ViewGroup.LayoutParams.MATCH_PARENT,
            Gravity.END
        );
        super.addView(indicator, indicatorParams);
        scrollView.setOnScrollChangeListener((view, left, top, oldLeft, oldTop) -> indicator.invalidate());
    }

    public void setContent(View content) {
        scrollView.removeAllViews();
        scrollView.addView(content, new ScrollView.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        indicator.invalidate();
    }

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int widthMode = MeasureSpec.getMode(widthMeasureSpec);
        int naturalWidthSpec = widthMode == MeasureSpec.UNSPECIFIED
            ? widthMeasureSpec
            : MeasureSpec.makeMeasureSpec(MeasureSpec.getSize(widthMeasureSpec), MeasureSpec.EXACTLY);

        scrollView.measure(
            naturalWidthSpec,
            MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        );

        int measuredWidth = resolveSize(
            Math.max(getSuggestedMinimumWidth(), scrollView.getMeasuredWidth()),
            widthMeasureSpec
        );
        scrollView.measure(
            MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        );

        int desiredHeight = Math.min(
            maximumHeight,
            Math.max(getSuggestedMinimumHeight(), scrollView.getMeasuredHeight())
        );
        int measuredHeight = resolveSize(desiredHeight, heightMeasureSpec);
        setMeasuredDimension(measuredWidth, measuredHeight);

        scrollView.measure(
            MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY)
        );
        indicator.measure(
            MeasureSpec.makeMeasureSpec(indicator.getLayoutParams().width, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY)
        );
    }

    private void drawTintedIndicator(Canvas canvas, int trackWidth, int trackHeight) {
        View content = scrollView.getChildCount() == 0 ? null : scrollView.getChildAt(0);
        int visibleHeight = scrollView.getHeight()
            - scrollView.getPaddingTop()
            - scrollView.getPaddingBottom();
        int childHeight = content == null ? 0 : content.getHeight();
        int contentHeight = childHeight + scrollView.getPaddingTop() + scrollView.getPaddingBottom();
        int maximumVisibleTop = Math.max(0, childHeight - visibleHeight);
        if (childHeight <= visibleHeight + overflowThreshold || trackHeight <= overflowThreshold) return;

        float proportionalHeight = trackHeight * (visibleHeight / (float) contentHeight);
        float thumbHeight = Math.min(trackHeight, Math.max(minimumThumbHeight, proportionalHeight));
        float scrollProgress = maximumVisibleTop == 0
            ? 0
            : Math.min(1, Math.max(0, scrollView.getScrollY() / (float) maximumVisibleTop));
        float thumbTop = (trackHeight - thumbHeight) * scrollProgress;
        float thumbLeft = trackWidth - indicatorWidth;
        float radius = indicatorWidth / 2f;

        canvas.drawRoundRect(
            thumbLeft,
            thumbTop,
            trackWidth,
            thumbTop + thumbHeight,
            radius,
            radius,
            indicatorPaint
        );
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private final class IndicatorView extends View {
        private IndicatorView(Context context) {
            super(context);
            setWillNotDraw(false);
        }

        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            drawTintedIndicator(canvas, getWidth(), getHeight());
        }
    }

    private static final class TouchCoordinatingScrollView extends ScrollView {
        private float previousTouchY;

        private TouchCoordinatingScrollView(Context context) {
            super(context);
        }

        @Override public boolean dispatchTouchEvent(MotionEvent event) {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    previousTouchY = event.getY();
                    getParent().requestDisallowInterceptTouchEvent(true);
                    break;
                case MotionEvent.ACTION_MOVE:
                    float nextY = event.getY();
                    int direction = previousTouchY > nextY ? 1 : -1;
                    getParent().requestDisallowInterceptTouchEvent(canScrollVertically(direction));
                    previousTouchY = nextY;
                    break;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    getParent().requestDisallowInterceptTouchEvent(false);
                    break;
                default:
                    break;
            }
            return super.dispatchTouchEvent(event);
        }
    }
}
