package org.keyvox.android.ime;

/** One key in the Android number and symbol layout. */
final class KeyboardKeySpec {
    enum Action {
        CHARACTER,
        DELETE,
        SPACE,
        ENTER,
        NEXT_KEYBOARD,
        ALTERNATE_SYMBOLS,
        NUMBER_SYMBOLS,
        RESTORE_FULL_KEYBOARD
    }

    final String label;
    final Action action;
    final float widthUnits;
    final boolean special;
    final int iconResource;
    final float iconSizeDp;
    final float contentVerticalOffsetDp;

    private KeyboardKeySpec(
        String label,
        Action action,
        float widthUnits,
        boolean special,
        int iconResource,
        float iconSizeDp,
        float contentVerticalOffsetDp
    ) {
        this.label = label;
        this.action = action;
        this.widthUnits = widthUnits;
        this.special = special;
        this.iconResource = iconResource;
        this.iconSizeDp = iconSizeDp;
        this.contentVerticalOffsetDp = contentVerticalOffsetDp;
    }

    static KeyboardKeySpec character(String value) {
        return character(value, 0);
    }

    static KeyboardKeySpec character(String value, float contentVerticalOffsetDp) {
        return new KeyboardKeySpec(value, Action.CHARACTER, 1, false, 0, 0, contentVerticalOffsetDp);
    }

    static KeyboardKeySpec action(String label, Action action, float widthUnits) {
        return new KeyboardKeySpec(label, action, widthUnits, true, 0, 0, 0);
    }

    static KeyboardKeySpec icon(int iconResource, Action action, float widthUnits) {
        float size = action == Action.RESTORE_FULL_KEYBOARD
            ? KeyboardStyle.RESTORE_KEYBOARD_ICON_DP
            : KeyboardStyle.KEY_ICON_DP;
        return new KeyboardKeySpec("", action, widthUnits, true, iconResource, size, 0);
    }
}
