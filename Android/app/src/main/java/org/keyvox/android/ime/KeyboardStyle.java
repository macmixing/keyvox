package org.keyvox.android.ime;

import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.util.TypedValue;

/** Shared visual tokens for the Android keyboard presentation. */
final class KeyboardStyle {
    static final int CANCEL = Color.rgb(255, 69, 58);

    static final float FULL_HEIGHT_DP = 286;
    static final float COMPACT_HEIGHT_DP = 174;
    static final float MAX_CONTENT_WIDTH_DP = 720;
    static final float HORIZONTAL_PADDING_DP = 4;
    static final float TOP_PADDING_DP = 8;
    static final float BOTTOM_PADDING_DP = 4;
    static final float KEY_HEIGHT_DP = 48;
    static final float KEY_SPACING_DP = 6;
    static final float ROW_SPACING_DP = 8;
    static final float KEY_RADIUS_DP = 8;
    static final float KEY_BORDER_DP = 0.5f;
    static final float KEY_ICON_DP = 22;
    static final float RESTORE_KEYBOARD_ICON_DP = 26;
    static final float LOGO_DIAMETER_DP = 53;
    static final float TOOLBAR_HEIGHT_DP = LOGO_DIAMETER_DP;

    static final Typeface KEY_TYPEFACE = Typeface.create("sans-serif", Typeface.NORMAL);

    private KeyboardStyle() {}

    static int dp(Context context, float value) {
        return Math.round(TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            context.getResources().getDisplayMetrics()
        ));
    }

    static float layoutScale(Context context) {
        float widthDp = context.getResources().getDisplayMetrics().widthPixels
            / context.getResources().getDisplayMetrics().density;
        return Math.min(1, widthDp / 440f);
    }

    static int layoutDp(Context context, float value) {
        return dp(context, value * layoutScale(context));
    }

    static boolean isDark(Context context) {
        return (context.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
            == Configuration.UI_MODE_NIGHT_YES;
    }

    static int background(Context context) {
        return isDark(context) ? Color.rgb(23, 23, 25) : Color.rgb(242, 242, 247);
    }

    static int text(Context context) {
        return isDark(context) ? Color.rgb(249, 249, 252) : Color.BLACK;
    }

    static int indigo(Context context) {
        return isDark(context) ? Color.rgb(94, 108, 230) : Color.rgb(88, 86, 214);
    }

    static int active(Context context) {
        return isDark(context) ? Color.rgb(255, 204, 0) : Color.rgb(184, 128, 0);
    }

    static int popupFill(Context context) {
        return isDark(context) ? Color.rgb(158, 161, 199) : Color.WHITE;
    }

    static int popupBorder(Context context) {
        return isDark(context) ? Color.argb(128, 255, 255, 255) : Color.argb(89, 107, 107, 112);
    }

    static int tenColumnLeft(Context context, int width, int column) {
        int spacing = layoutDp(context, KEY_SPACING_DP);
        int keyPixels = width - spacing * 9;
        return column * spacing + Math.round(keyPixels * column / 10f);
    }

    static int tenColumnRight(Context context, int width, int column) {
        int spacing = layoutDp(context, KEY_SPACING_DP);
        int keyPixels = width - spacing * 9;
        return column * spacing + Math.round(keyPixels * (column + 1) / 10f);
    }

    static GradientDrawable keyBackground(Context context, boolean special, boolean pressed) {
        GradientDrawable drawable = new GradientDrawable();
        int fill;
        if (isDark(context)) {
            fill = pressed ? Color.rgb(47, 49, 88) : special ? Color.rgb(55, 55, 79) : Color.rgb(84, 84, 103);
        } else if (pressed) {
            fill = special ? Color.rgb(168, 169, 187) : Color.rgb(180, 182, 207);
        } else {
            fill = special ? Color.rgb(195, 196, 219) : Color.rgb(229, 229, 244);
        }
        drawable.setCornerRadius(layoutDp(context, KEY_RADIUS_DP));
        drawable.setColor(fill);
        int border = isDark(context) ? Color.rgb(112, 112, 132) : Color.argb(89, 107, 107, 112);
        drawable.setStroke(Math.max(1, layoutDp(context, KEY_BORDER_DP)), border);
        return drawable;
    }
}
