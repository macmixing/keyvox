package org.keyvox.android.app.dictionary;

import android.content.Context;
import android.graphics.Outline;
import android.graphics.drawable.ColorDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewGroup;
import android.view.ViewOutlineProvider;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.animation.PathInterpolator;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.function.Consumer;
import org.keyvox.android.R;

/** A clipped phrase row whose actions travel in from its trailing edge. */
final class DictionarySwipeEntryRowView extends FrameLayout {
    private static final float ACTION_WIDTH_DP = 62;
    private static final float ROW_HEIGHT_DP = 62;

    private final DictionaryEntry entry;
    private final Runnable edit;
    private final Runnable delete;
    private final Consumer<DictionarySwipeEntryRowView> interactionBegan;
    private final LinearLayout actions;
    private final TextView content;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final int touchSlop;
    private final Runnable presentContextMenu = this::presentContextMenu;
    private float downX;
    private float downY;
    private float startingOffset;
    private boolean horizontalDrag;
    private boolean contextMenuPresented;

    DictionarySwipeEntryRowView(
        Context context,
        DictionaryEntry entry,
        Runnable edit,
        Runnable delete,
        Consumer<DictionarySwipeEntryRowView> interactionBegan
    ) {
        super(context);
        this.entry = entry;
        this.edit = edit;
        this.delete = delete;
        this.interactionBegan = interactionBegan;
        touchSlop = ViewConfiguration.get(context).getScaledTouchSlop();
        setClipToOutline(true);
        setOutlineProvider(new ViewOutlineProvider() {
            @Override public void getOutline(View view, Outline outline) {
                outline.setRoundRect(0, 0, view.getWidth(), view.getHeight(), dp(10));
            }
        });

        actions = new LinearLayout(context);
        actions.setGravity(Gravity.END);
        actions.addView(actionButton(R.drawable.ic_edit, R.color.app_accent, R.string.edit, edit),
            new LinearLayout.LayoutParams(dp(ACTION_WIDTH_DP), dp(ROW_HEIGHT_DP)));
        actions.addView(actionButton(R.drawable.ic_delete, R.color.app_error, R.string.delete, delete),
            new LinearLayout.LayoutParams(dp(ACTION_WIDTH_DP), dp(ROW_HEIGHT_DP)));
        updateActionAccessibility(false);
        addView(actions, new FrameLayout.LayoutParams(
            dp(ACTION_WIDTH_DP * 2),
            dp(ROW_HEIGHT_DP),
            Gravity.END
        ));

        content = new TextView(context) {
            @Override public boolean onTouchEvent(MotionEvent event) {
                boolean click = event.getActionMasked() == MotionEvent.ACTION_UP
                    && !horizontalDrag
                    && !contextMenuPresented;
                boolean handled = handleTouch(event);
                if (click) performClick();
                return handled;
            }

            @Override public boolean performClick() {
                return super.performClick();
            }
        };
        content.setText(entry.phrase());
        content.setTextColor(getColor(R.color.app_primary_text));
        content.setTextSize(18.4f);
        content.setTypeface(getResources().getFont(R.font.kanit_light));
        content.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        content.setPadding(dp(22), 0, dp(22), 0);
        content.setBackgroundResource(R.drawable.app_dictionary_row_content_background);
        content.setOnLongClickListener(ignored -> {
            presentContextMenu();
            return true;
        });
        content.setAccessibilityDelegate(new View.AccessibilityDelegate() {
            @Override public void onInitializeAccessibilityNodeInfo(
                View host,
                AccessibilityNodeInfo info
            ) {
                super.onInitializeAccessibilityNodeInfo(host, info);
                info.addAction(new AccessibilityNodeInfo.AccessibilityAction(
                    R.id.dictionary_accessibility_edit,
                    getContext().getString(R.string.edit)
                ));
                info.addAction(new AccessibilityNodeInfo.AccessibilityAction(
                    R.id.dictionary_accessibility_delete,
                    getContext().getString(R.string.delete)
                ));
            }

            @Override public boolean performAccessibilityAction(
                View host,
                int action,
                Bundle arguments
            ) {
                if (action == R.id.dictionary_accessibility_edit) {
                    settle(false);
                    edit.run();
                    return true;
                }
                if (action == R.id.dictionary_accessibility_delete) {
                    settle(false);
                    delete.run();
                    return true;
                }
                return super.performAccessibilityAction(host, action, arguments);
            }
        });
        addView(content, new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(ROW_HEIGHT_DP)
        ));
    }

    private boolean handleTouch(MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                content.animate().cancel();
                interactionBegan.accept(this);
                downX = event.getRawX();
                downY = event.getRawY();
                startingOffset = content.getTranslationX();
                horizontalDrag = false;
                contextMenuPresented = false;
                handler.postDelayed(presentContextMenu, ViewConfiguration.getLongPressTimeout());
                return true;
            case MotionEvent.ACTION_MOVE:
                float horizontal = event.getRawX() - downX;
                float vertical = event.getRawY() - downY;
                if (!horizontalDrag && Math.abs(horizontal) > touchSlop
                    && Math.abs(horizontal) > Math.abs(vertical)) {
                    horizontalDrag = true;
                    handler.removeCallbacks(presentContextMenu);
                    getParent().requestDisallowInterceptTouchEvent(true);
                } else if (!horizontalDrag && Math.abs(vertical) > touchSlop) {
                    handler.removeCallbacks(presentContextMenu);
                }
                if (horizontalDrag) setOffset(startingOffset + horizontal);
                return true;
            case MotionEvent.ACTION_UP:
                handler.removeCallbacks(presentContextMenu);
                getParent().requestDisallowInterceptTouchEvent(false);
                if (horizontalDrag) {
                    float completedDistance = event.getRawX() - downX;
                    if (completedDistance >= dp(10)) {
                        settle(false);
                    } else if (completedDistance <= -dp(10)) {
                        settle(true);
                    } else {
                        settle(content.getTranslationX() < -dp(ACTION_WIDTH_DP));
                    }
                } else if (!contextMenuPresented && content.getTranslationX() < 0) {
                    settle(false);
                }
                return true;
            case MotionEvent.ACTION_CANCEL:
                handler.removeCallbacks(presentContextMenu);
                getParent().requestDisallowInterceptTouchEvent(false);
                if (horizontalDrag) settle(content.getTranslationX() < -dp(ACTION_WIDTH_DP));
                return true;
            default:
                return true;
        }
    }

    private boolean handleActionTouch(View button, MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                content.animate().cancel();
                interactionBegan.accept(this);
                downX = event.getRawX();
                downY = event.getRawY();
                startingOffset = content.getTranslationX();
                horizontalDrag = false;
                return true;
            case MotionEvent.ACTION_MOVE:
                float horizontal = event.getRawX() - downX;
                float vertical = event.getRawY() - downY;
                if (!horizontalDrag && Math.abs(horizontal) > touchSlop
                    && Math.abs(horizontal) > Math.abs(vertical)) {
                    horizontalDrag = true;
                    getParent().requestDisallowInterceptTouchEvent(true);
                }
                if (horizontalDrag) {
                    setOffset(startingOffset + horizontal);
                }
                return true;
            case MotionEvent.ACTION_UP:
                if (!horizontalDrag) return true;
                getParent().requestDisallowInterceptTouchEvent(false);
                float completedDistance = event.getRawX() - downX;
                if (completedDistance >= dp(10)) settle(false);
                else if (completedDistance <= -dp(10)) settle(true);
                else settle(content.getTranslationX() < -dp(ACTION_WIDTH_DP));
                return true;
            case MotionEvent.ACTION_CANCEL:
                if (horizontalDrag) settle(content.getTranslationX() < -dp(ACTION_WIDTH_DP));
                getParent().requestDisallowInterceptTouchEvent(false);
                return true;
            default:
                return true;
        }
    }

    private void setOffset(float requestedOffset) {
        float totalWidth = dp(ACTION_WIDTH_DP * 2);
        float offset = Math.max(-totalWidth, Math.min(0, requestedOffset));
        content.setTranslationX(offset);
    }

    private void settle(boolean reveal) {
        float totalWidth = dp(ACTION_WIDTH_DP * 2);
        float target = reveal ? -totalWidth : 0;
        content.animate().cancel();
        updateActionAccessibility(reveal);
        PathInterpolator easing = new PathInterpolator(0.2f, 0f, 0f, 1f);
        content.animate()
            .translationX(target)
            .setDuration(220)
            .setInterpolator(easing)
            .start();
    }

    void closeActions() {
        settle(false);
    }

    void closeActionsImmediately() {
        content.animate().cancel();
        setOffset(0);
        updateActionAccessibility(false);
    }

    private void updateActionAccessibility(boolean actionsRevealed) {
        actions.setImportantForAccessibility(actionsRevealed
            ? View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
            : View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
    }

    private void presentContextMenu() {
        interactionBegan.accept(this);
        contextMenuPresented = true;
        content.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS);
        DictionaryEntryContextMenu.show(content, entry, edit, delete);
    }

    private ImageButton actionButton(int icon, int backgroundColor, int label, Runnable action) {
        ImageButton button = new ImageButton(getContext()) {
            @Override public boolean onTouchEvent(MotionEvent event) {
                if (event.getActionMasked() == MotionEvent.ACTION_UP && !horizontalDrag) {
                    performClick();
                    return true;
                }
                return handleActionTouch(this, event);
            }

            @Override public boolean performClick() {
                return super.performClick();
            }
        };
        button.setImageResource(icon);
        button.setImageTintList(android.content.res.ColorStateList.valueOf(0xFFFFFFFF));
        button.setBackground(new ColorDrawable(getColor(backgroundColor)));
        button.setContentDescription(getContext().getString(label));
        button.setOnClickListener(ignored -> {
            settle(false);
            action.run();
        });
        return button;
    }

    private int getColor(int id) { return getResources().getColor(id, getContext().getTheme()); }
    private int dp(float value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
