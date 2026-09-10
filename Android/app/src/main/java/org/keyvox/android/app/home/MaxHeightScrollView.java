package org.keyvox.android.app.home;

import android.content.Context;
import android.view.MotionEvent;
import android.widget.ScrollView;

/** Allows transcription content to grow naturally until its established height cap. */
final class MaxHeightScrollView extends ScrollView {
    private final int maximumHeight;
    private float previousTouchY;

    MaxHeightScrollView(Context context, int maximumHeight) {
        super(context);
        this.maximumHeight = maximumHeight;
        setFillViewport(true);
        setVerticalScrollBarEnabled(false);
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

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int cappedHeight = MeasureSpec.makeMeasureSpec(maximumHeight, MeasureSpec.AT_MOST);
        super.onMeasure(widthMeasureSpec, cappedHeight);
    }
}
