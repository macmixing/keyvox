package org.keyvox.android.ime;

import android.content.Context;
import android.content.res.ColorStateList;
import android.os.Build;
import android.view.HapticFeedbackConstants;
import android.widget.ImageButton;
import java.util.function.BooleanSupplier;
import org.keyvox.android.R;

/** Shared visual treatment for square keyboard toolbar controls. */
final class KeyboardIconButton extends ImageButton {
    enum TintRole { FOREGROUND, ACTIVE, CANCEL }

    private final boolean interactive;
    private final CharSequence label;
    private TintRole tintRole;

    KeyboardIconButton(Context context, int iconResource, TintRole tintRole, CharSequence label, Runnable action) {
        this(
            context,
            iconResource,
            tintRole,
            label,
            action == null ? null : () -> {
                action.run();
                return true;
            },
            null
        );
    }

    KeyboardIconButton(
            Context context,
            int iconResource,
            TintRole tintRole,
            CharSequence label,
            BooleanSupplier action,
            BooleanSupplier longPressAction) {
        super(context);
        interactive = action != null || longPressAction != null;
        this.label = label;
        this.tintRole = tintRole;
        setImageResource(iconResource);
        setContentDescription(label);
        setPadding(
            KeyboardStyle.layoutDp(context, 7),
            KeyboardStyle.layoutDp(context, 7),
            KeyboardStyle.layoutDp(context, 7),
            KeyboardStyle.layoutDp(context, 7)
        );
        setScaleType(ScaleType.CENTER_INSIDE);
        setBackground(KeyboardStyle.toolbarButtonBackground(context, false));
        setElevation(KeyboardStyle.layoutDp(context, 1));
        setFocusable(false);
        setClickable(interactive);
        if (action != null) {
            setOnClickListener(view -> {
                if (action.getAsBoolean()) {
                    performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
                }
            });
        }
        if (longPressAction != null) {
            setLongClickable(true);
            setOnLongClickListener(view -> {
                boolean changed = longPressAction.getAsBoolean();
                performHapticFeedback(changed
                    ? HapticFeedbackConstants.LONG_PRESS
                    : HapticFeedbackConstants.CLOCK_TICK);
                return true;
            });
        }
        refreshAppearance();
    }

    void setToggleState(boolean on) {
        tintRole = on ? TintRole.ACTIVE : TintRole.FOREGROUND;
        CharSequence state = getContext().getString(
            on ? R.string.keyboard_state_on : R.string.keyboard_state_off);
        if (Build.VERSION.SDK_INT >= 30) {
            setContentDescription(label);
            setStateDescription(state);
        } else {
            setContentDescription(getContext().getString(
                R.string.keyboard_toggle_accessibility,
                label,
                state
            ));
        }
        refreshAppearance();
    }

    void refreshAppearance() {
        int tint;
        switch (tintRole) {
            case ACTIVE: tint = KeyboardStyle.active(getContext()); break;
            case CANCEL: tint = KeyboardStyle.CANCEL; break;
            case FOREGROUND:
            default: tint = KeyboardStyle.text(getContext()); break;
        }
        setImageTintList(ColorStateList.valueOf(tint));
        setBackground(KeyboardStyle.toolbarButtonBackground(getContext(), isPressed()));
    }

    @Override protected void drawableStateChanged() {
        super.drawableStateChanged();
        if (!interactive) return;
        boolean pressed = isPressed();
        setScaleX(pressed ? 0.985f : 1);
        setScaleY(pressed ? 0.96f : 1);
        setBackground(KeyboardStyle.toolbarButtonBackground(getContext(), pressed));
    }
}
