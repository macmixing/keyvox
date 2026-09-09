package org.keyvox.android.ime;

import android.content.Context;
import android.content.res.ColorStateList;
import android.view.HapticFeedbackConstants;
import android.widget.ImageButton;

/** Shared visual treatment for square keyboard toolbar controls. */
final class KeyboardIconButton extends ImageButton {
    enum TintRole { FOREGROUND, ACTIVE, CANCEL }

    private final boolean interactive;
    private final TintRole tintRole;

    KeyboardIconButton(Context context, int iconResource, TintRole tintRole, CharSequence label, Runnable action) {
        super(context);
        interactive = action != null;
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
        setBackground(KeyboardStyle.keyBackground(context, false, false));
        setElevation(KeyboardStyle.layoutDp(context, 1));
        setFocusable(false);
        setClickable(interactive);
        if (action != null) {
            setOnClickListener(view -> {
                performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
                action.run();
            });
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
        setBackground(KeyboardStyle.keyBackground(getContext(), false, isPressed()));
    }

    @Override protected void drawableStateChanged() {
        super.drawableStateChanged();
        if (!interactive) return;
        boolean pressed = isPressed();
        setScaleX(pressed ? 0.985f : 1);
        setScaleY(pressed ? 0.96f : 1);
        setBackground(KeyboardStyle.keyBackground(getContext(), false, pressed));
    }
}
