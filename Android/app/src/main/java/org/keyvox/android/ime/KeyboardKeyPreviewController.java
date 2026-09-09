package org.keyvox.android.ime;

import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.PopupWindow;
import android.widget.TextView;

/** Owns the transient character preview shown above a pressed key. */
final class KeyboardKeyPreviewController {
    private PopupWindow popup;

    void show(View anchor, CharSequence text) {
        dismiss();
        TextView label = new TextView(anchor.getContext());
        label.setGravity(Gravity.CENTER);
        label.setText(text);
        label.setTextColor(Color.BLACK);
        label.setTextSize(32 * KeyboardStyle.layoutScale(anchor.getContext()));
        label.setTypeface(KeyboardStyle.KEY_TYPEFACE);
        label.setIncludeFontPadding(false);

        GradientDrawable background = new GradientDrawable();
        background.setColor(KeyboardStyle.popupFill(anchor.getContext()));
        background.setCornerRadius(KeyboardStyle.layoutDp(anchor.getContext(), 10));
        background.setStroke(KeyboardStyle.layoutDp(anchor.getContext(), 1), KeyboardStyle.popupBorder(anchor.getContext()));
        label.setBackground(background);
        label.setElevation(KeyboardStyle.layoutDp(anchor.getContext(), 4));

        int width = Math.max(
            Math.round(anchor.getWidth() * 1.15f),
            KeyboardStyle.layoutDp(anchor.getContext(), 44)
        );
        int height = Math.max(
            Math.round(anchor.getHeight() * 1.25f),
            KeyboardStyle.layoutDp(anchor.getContext(), 52)
        );
        popup = new PopupWindow(label, width, height, false);
        popup.setClippingEnabled(false);
        popup.setElevation(KeyboardStyle.layoutDp(anchor.getContext(), 5));
        popup.showAsDropDown(
            anchor,
            (anchor.getWidth() - width) / 2,
            -anchor.getHeight() - height - KeyboardStyle.layoutDp(anchor.getContext(), 3)
        );
    }

    void dismiss() {
        if (popup == null) return;
        popup.dismiss();
        popup = null;
    }
}
