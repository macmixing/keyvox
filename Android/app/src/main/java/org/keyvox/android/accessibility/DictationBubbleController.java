package org.keyvox.android.accessibility;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Insets;
import android.graphics.PixelFormat;
import android.graphics.PointF;
import android.graphics.Rect;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.view.WindowMetrics;
import org.keyvox.android.dictation.DictationLogoBarView;
import org.keyvox.android.dictation.DictationSession;

/** Owns the accessibility overlay window, its appearance, and persisted drag position. */
final class DictationBubbleController {
    private static final String PREFERENCES = "dictation_bubble";
    private static final String X_FRACTION = "x_fraction";
    private static final String Y_FRACTION = "y_fraction";
    private static final float DEFAULT_X_FRACTION = 0.92f;
    private static final float DEFAULT_Y_FRACTION = 0.68f;

    private final Context context;
    private final WindowManager windowManager;
    private final SharedPreferences preferences;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final DictationLogoBarView view;
    private final WindowManager.LayoutParams parameters;
    private final int touchSlop;
    private final BubbleDragVelocity dragVelocity = new BubbleDragVelocity();
    private final BubbleMotionController motion;
    private boolean attached;
    private boolean dragging;
    private boolean gestureMoved;
    private float downRawX;
    private float downRawY;
    private int downWindowX;
    private int downWindowY;

    DictationBubbleController(Context context, Runnable action) {
        this.context = context;
        windowManager = context.getSystemService(WindowManager.class);
        preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
        view = new DictationLogoBarView(context, action);
        int size = DictationLogoBarView.preferredSizePx(context);
        parameters = new WindowManager.LayoutParams(
            size,
            size,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        );
        parameters.gravity = Gravity.TOP | Gravity.START;
        touchSlop = ViewConfiguration.get(context).getScaledTouchSlop();
        motion = new BubbleMotionController(
            context.getResources().getDisplayMetrics().density,
            this::updatePosition
        );
        view.setOnTouchListener(this::handleTouch);
    }

    void attach() {
        if (attached) return;
        restorePosition();
        windowManager.addView(view, parameters);
        attached = true;
    }

    void render(DictationSession session) {
        view.render(session);
    }

    void configurationChanged() {
        motion.cancel();
        int size = DictationLogoBarView.preferredSizePx(context);
        parameters.width = size;
        parameters.height = size;
        clampPosition();
        view.refreshAppearance();
        if (attached) windowManager.updateViewLayout(view, parameters);
    }

    void detach() {
        main.removeCallbacksAndMessages(null);
        motion.cancel();
        dragVelocity.clear();
        if (attached) windowManager.removeView(view);
        attached = false;
    }

    private boolean handleTouch(View ignored, MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                motion.cancel();
                downRawX = event.getRawX();
                downRawY = event.getRawY();
                downWindowX = parameters.x;
                downWindowY = parameters.y;
                dragging = false;
                gestureMoved = false;
                main.postDelayed(this::beginDrag, ViewConfiguration.getLongPressTimeout());
                return true;
            case MotionEvent.ACTION_MOVE:
                float deltaX = event.getRawX() - downRawX;
                float deltaY = event.getRawY() - downRawY;
                if (!dragging && Math.hypot(deltaX, deltaY) > touchSlop) {
                    gestureMoved = true;
                    main.removeCallbacksAndMessages(null);
                }
                if (dragging) {
                    dragVelocity.append(event.getRawX(), event.getRawY(), event.getEventTime());
                    parameters.x = downWindowX + Math.round(deltaX);
                    parameters.y = downWindowY + Math.round(deltaY);
                    clampPosition();
                    windowManager.updateViewLayout(view, parameters);
                }
                return true;
            case MotionEvent.ACTION_UP:
                main.removeCallbacksAndMessages(null);
                if (dragging) {
                    dragVelocity.append(event.getRawX(), event.getRawY(), event.getEventTime());
                    PointF velocity = dragVelocity.releaseVelocity();
                    Rect movementArea = movementArea();
                    boolean flung = velocity != null && motion.fling(
                        parameters.x,
                        parameters.y,
                        velocity.x,
                        velocity.y,
                        movementArea,
                        this::savePosition
                    );
                    if (!flung) savePosition();
                }
                else if (!gestureMoved) view.performClick();
                dragVelocity.clear();
                dragging = false;
                gestureMoved = false;
                return true;
            case MotionEvent.ACTION_CANCEL:
                main.removeCallbacksAndMessages(null);
                dragVelocity.clear();
                dragging = false;
                gestureMoved = false;
                return true;
            default:
                return false;
        }
    }

    private void beginDrag() {
        dragging = true;
        dragVelocity.begin(downRawX, downRawY, android.os.SystemClock.uptimeMillis());
        view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS);
    }

    private void updatePosition(int x, int y) {
        if (!attached) return;
        parameters.x = x;
        parameters.y = y;
        windowManager.updateViewLayout(view, parameters);
    }

    private void restorePosition() {
        Rect area = movementArea();
        parameters.x = BubblePosition.coordinate(
            area.left,
            area.width(),
            preferences.getFloat(X_FRACTION, DEFAULT_X_FRACTION)
        );
        parameters.y = BubblePosition.coordinate(
            area.top,
            area.height(),
            preferences.getFloat(Y_FRACTION, DEFAULT_Y_FRACTION)
        );
        clampPosition();
    }

    private void savePosition() {
        Rect area = movementArea();
        float x = BubblePosition.fraction(parameters.x, area.left, area.width());
        float y = BubblePosition.fraction(parameters.y, area.top, area.height());
        preferences.edit()
            .putFloat(X_FRACTION, x)
            .putFloat(Y_FRACTION, y)
            .apply();
    }

    private void clampPosition() {
        Rect area = movementArea();
        parameters.x = BubblePosition.clampX(parameters.x, area);
        parameters.y = BubblePosition.clampY(parameters.y, area);
    }

    private Rect movementArea() {
        int width;
        int height;
        int left = 0;
        int top = 0;
        int rightInset = 0;
        int bottomInset = 0;
        if (Build.VERSION.SDK_INT >= 30) {
            WindowMetrics metrics = windowManager.getCurrentWindowMetrics();
            Rect bounds = metrics.getBounds();
            Insets insets = metrics.getWindowInsets().getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout()
            );
            width = bounds.width();
            height = bounds.height();
            left = insets.left;
            top = insets.top;
            rightInset = insets.right;
            bottomInset = insets.bottom;
        } else {
            width = context.getResources().getDisplayMetrics().widthPixels;
            height = context.getResources().getDisplayMetrics().heightPixels;
        }
        return BubblePosition.movementArea(
            width,
            height,
            left,
            top,
            rightInset,
            bottomInset,
            parameters.width,
            parameters.height
        );
    }

}
