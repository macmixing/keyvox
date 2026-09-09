package org.keyvox.android.ime;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.keyvox.android.R;

/** Source of truth for the Android number, symbol, and compact key rows. */
final class KeyboardSymbolLayout {
    enum Page { PRIMARY, ALTERNATE }

    private KeyboardSymbolLayout() {}

    static List<List<KeyboardKeySpec>> rows(Page page, boolean compact) {
        if (compact) return compactRows();
        return page == Page.PRIMARY ? primaryRows() : alternateRows();
    }

    private static List<List<KeyboardKeySpec>> primaryRows() {
        return Arrays.asList(
            characters("1", "2", "3", "4", "5", "6", "7", "8", "9", "0"),
            actions(
                KeyboardKeySpec.character("-"),
                KeyboardKeySpec.character("/"),
                KeyboardKeySpec.character(":"),
                KeyboardKeySpec.character(";"),
                KeyboardKeySpec.character("("),
                KeyboardKeySpec.character(")"),
                KeyboardKeySpec.character("$"),
                KeyboardKeySpec.character("&"),
                KeyboardKeySpec.character("@", -1),
                KeyboardKeySpec.character("\"")
            ),
            actions(
                KeyboardKeySpec.action("#+=", KeyboardKeySpec.Action.ALTERNATE_SYMBOLS, 1.45f),
                KeyboardKeySpec.character("."),
                KeyboardKeySpec.character(","),
                KeyboardKeySpec.character("?"),
                KeyboardKeySpec.character("!"),
                KeyboardKeySpec.character("‘"),
                KeyboardKeySpec.icon(R.drawable.ic_keyboard_backspace, KeyboardKeySpec.Action.DELETE, 1.45f)
            ),
            bottomRow()
        );
    }

    private static List<List<KeyboardKeySpec>> alternateRows() {
        return Arrays.asList(
            characters("[", "]", "{", "}", "#", "%", "^", "*", "+", "="),
            characters("_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"),
            actions(
                KeyboardKeySpec.action("123", KeyboardKeySpec.Action.NUMBER_SYMBOLS, 1.45f),
                KeyboardKeySpec.character("."),
                KeyboardKeySpec.character(","),
                KeyboardKeySpec.character("?"),
                KeyboardKeySpec.character("!"),
                KeyboardKeySpec.character("’"),
                KeyboardKeySpec.icon(R.drawable.ic_keyboard_backspace, KeyboardKeySpec.Action.DELETE, 1.45f)
            ),
            bottomRow()
        );
    }

    private static List<List<KeyboardKeySpec>> compactRows() {
        return Arrays.asList(
            actions(
                KeyboardKeySpec.icon(R.drawable.ic_keyboard, KeyboardKeySpec.Action.RESTORE_FULL_KEYBOARD, 1.45f),
                KeyboardKeySpec.character("."),
                KeyboardKeySpec.character(","),
                KeyboardKeySpec.character("?"),
                KeyboardKeySpec.character("!"),
                KeyboardKeySpec.character("‘"),
                KeyboardKeySpec.icon(R.drawable.ic_keyboard_backspace, KeyboardKeySpec.Action.DELETE, 1.45f)
            ),
            bottomRow()
        );
    }

    private static List<KeyboardKeySpec> bottomRow() {
        return actions(
            KeyboardKeySpec.action("ABC", KeyboardKeySpec.Action.NEXT_KEYBOARD, 2.5f),
            KeyboardKeySpec.action("", KeyboardKeySpec.Action.SPACE, 5),
            KeyboardKeySpec.icon(R.drawable.ic_keyboard_return, KeyboardKeySpec.Action.ENTER, 2.5f)
        );
    }

    private static List<KeyboardKeySpec> characters(String... values) {
        List<KeyboardKeySpec> keys = new ArrayList<>();
        for (String value : values) keys.add(KeyboardKeySpec.character(value));
        return keys;
    }

    private static List<KeyboardKeySpec> actions(KeyboardKeySpec... values) {
        return Arrays.asList(values);
    }
}
