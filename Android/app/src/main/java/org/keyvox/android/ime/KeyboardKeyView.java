package org.keyvox.android.ime;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.os.Looper;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;
import android.view.accessibility.AccessibilityEvent;
import android.widget.TextView;

/** Visual and touch behavior for one keyboard key. */
final class KeyboardKeyView extends TextView {
    interface Action { boolean run(); }

    private static final long LONG_PRESS_MILLIS = 500;
    private static final long DELETE_REPEAT_DELAY_MILLIS = 420;
    private static final long DELETE_REPEAT_INTERVAL_MILLIS = 85;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final boolean special;
    private final boolean repeats;
    private final Action action;
    private final Runnable longPressAction;
    private final CharSequence previewText;
    private final KeyboardKeyPreviewController previewController;
    private final Drawable icon;
    private final float iconSizeDp;
    private final float contentVerticalOffsetDp;
    private final Runnable longPress;
    private final Runnable deleteRepeat;
    private boolean longPressTriggered;
    private boolean deleteRepeatTriggered;
    private boolean touchActive;

    KeyboardKeyView(
        Context context,
        KeyboardKeySpec spec,
        CharSequence accessibilityLabel,
        Action action,
        Runnable longPressAction
    ) {
        super(context);
        this.special = spec.special;
        this.repeats = spec.action == KeyboardKeySpec.Action.DELETE;
        this.action = action;
        this.longPressAction = longPressAction;
        previewText = spec.action == KeyboardKeySpec.Action.CHARACTER ? spec.label : null;
        previewController = new KeyboardKeyPreviewController();
        icon = spec.iconResource == 0 ? null : context.getDrawable(spec.iconResource);
        iconSizeDp = spec.iconSizeDp;
        contentVerticalOffsetDp = spec.contentVerticalOffsetDp;
        longPress = () -> {
            if (!touchActive || this.longPressAction == null) return;
            longPressTriggered = true;
            performHapticFeedback(HapticFeedbackConstants.LONG_PRESS);
            this.longPressAction.run();
        };
        deleteRepeat = new Runnable() {
            @Override public void run() {
                if (!touchActive) return;
                deleteRepeatTriggered = true;
                if (!activate()) {
                    cancelPendingActions();
                    applyPressed(false);
                    return;
                }
                handler.postDelayed(this, DELETE_REPEAT_INTERVAL_MILLIS);
            }
        };

        setGravity(android.view.Gravity.CENTER);
        setText(spec.label);
        setTextColor(KeyboardStyle.text(context));
        setTextSize((spec.special ? 17 : 22) * KeyboardStyle.layoutScale(context));
        setTypeface(KeyboardStyle.KEY_TYPEFACE);
        setIncludeFontPadding(false);
        setPadding(0, 0, 0, 0);
        setContentDescription(accessibilityLabel);
        setClickable(true);
        setFocusable(false);
        setBackground(KeyboardStyle.keyBackground(context, special, false));
        setElevation(KeyboardStyle.layoutDp(context, 1));

        if (icon != null) icon.setTint(KeyboardStyle.text(context));

        setOnTouchListener(this::handleTouch);
    }

    @Override protected void onDraw(Canvas canvas) {
        int saveCount = canvas.save();
        canvas.translate(0, KeyboardStyle.layoutDp(getContext(), contentVerticalOffsetDp));
        super.onDraw(canvas);
        if (icon != null) {
            int iconSize = KeyboardStyle.layoutDp(getContext(), iconSizeDp);
            int left = (getWidth() - iconSize) / 2;
            int top = (getHeight() - iconSize) / 2;
            icon.setBounds(left, top, left + iconSize, top + iconSize);
            icon.draw(canvas);
        }
        canvas.restoreToCount(saveCount);
    }

    @Override public boolean performClick() {
        super.performClick();
        if (!repeats) activate();
        sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_CLICKED);
        return true;
    }

    void refreshAppearance() {
        setTextColor(KeyboardStyle.text(getContext()));
        if (icon != null) icon.setTint(KeyboardStyle.text(getContext()));
        setBackground(KeyboardStyle.keyBackground(getContext(), special, isPressed()));
        invalidate();
    }

    private boolean handleTouch(View ignored, MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                touchActive = true;
                longPressTriggered = false;
                deleteRepeatTriggered = false;
                applyPressed(true);
                if (previewText != null) previewController.show(this, previewText);
                if (repeats) {
                    handler.postDelayed(deleteRepeat, DELETE_REPEAT_DELAY_MILLIS);
                } else if (longPressAction != null) {
                    handler.postDelayed(longPress, LONG_PRESS_MILLIS);
                }
                return true;
            case MotionEvent.ACTION_UP:
                boolean wasActive = touchActive;
                cancelPendingActions();
                applyPressed(false);
                if (wasActive && repeats && !deleteRepeatTriggered) activate();
                if (wasActive && !repeats && !longPressTriggered) performClick();
                return true;
            case MotionEvent.ACTION_CANCEL:
                cancelPendingActions();
                applyPressed(false);
                return true;
            default:
                return true;
        }
    }

    private boolean activate() {
        if (!repeats) performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
        boolean performed = action.run();
        if (repeats && performed) performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
        return performed;
    }

    private void applyPressed(boolean pressed) {
        setPressed(pressed);
        setScaleX(pressed ? 0.985f : 1);
        setScaleY(pressed ? 0.96f : 1);
        setElevation(KeyboardStyle.layoutDp(getContext(), pressed ? 2 : 1));
        setBackground(KeyboardStyle.keyBackground(getContext(), special, pressed));
    }

    private void cancelPendingActions() {
        touchActive = false;
        handler.removeCallbacks(longPress);
        handler.removeCallbacks(deleteRepeat);
        previewController.dismiss();
    }

}
