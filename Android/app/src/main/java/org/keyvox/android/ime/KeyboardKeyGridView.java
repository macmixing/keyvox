package org.keyvox.android.ime;

import android.content.Context;
import android.content.SharedPreferences;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import java.util.List;
import org.keyvox.android.R;

/** Renders the working number, symbol, and compact keyboard rows. */
final class KeyboardKeyGridView extends LinearLayout {
    interface Listener {
        void insertText(String text);
        boolean deleteBackward();
        void switchToNextKeyboard();
    }

    private static final String PREFERENCES = "keyvox_keyboard";
    private static final String COMPACT_KEY = "compact_active";

    private final Listener listener;
    private final SharedPreferences preferences;
    private KeyboardSymbolLayout.Page page = KeyboardSymbolLayout.Page.PRIMARY;
    private boolean compact;

    KeyboardKeyGridView(Context context, Listener listener) {
        super(context);
        this.listener = listener;
        preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
        compact = preferences.getBoolean(COMPACT_KEY, false);
        setOrientation(VERTICAL);
        rebuild();
    }

    boolean isCompact() { return compact; }

    void refreshAppearance() {
        for (int rowIndex = 0; rowIndex < getChildCount(); rowIndex++) {
            if (!(getChildAt(rowIndex) instanceof KeyboardKeyRowView)) continue;
            KeyboardKeyRowView row = (KeyboardKeyRowView) getChildAt(rowIndex);
            for (int keyIndex = 0; keyIndex < row.getChildCount(); keyIndex++) {
                if (row.getChildAt(keyIndex) instanceof KeyboardKeyView) {
                    ((KeyboardKeyView) row.getChildAt(keyIndex)).refreshAppearance();
                }
            }
        }
    }

    private void rebuild() {
        removeAllViews();
        List<List<KeyboardKeySpec>> rows = KeyboardSymbolLayout.rows(page, compact);
        for (int rowIndex = 0; rowIndex < rows.size(); rowIndex++) {
            KeyboardKeyRowView row = new KeyboardKeyRowView(getContext());
            LayoutParams rowParams = new LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                KeyboardStyle.layoutDp(getContext(), KeyboardStyle.KEY_HEIGHT_DP)
            );
            if (rowIndex > 0) rowParams.topMargin = KeyboardStyle.layoutDp(getContext(), KeyboardStyle.ROW_SPACING_DP);
            addView(row, rowParams);

            List<KeyboardKeySpec> keys = rows.get(rowIndex);
            for (int keyIndex = 0; keyIndex < keys.size(); keyIndex++) {
                KeyboardKeySpec spec = keys.get(keyIndex);
                KeyboardKeyView key = new KeyboardKeyView(
                    getContext(),
                    spec,
                    accessibilityLabel(spec),
                    () -> activate(spec),
                    spec.action == KeyboardKeySpec.Action.ALTERNATE_SYMBOLS ? this::enterCompactMode : null
                );
                row.addKey(key, spec.widthUnits);
            }
        }
    }

    private boolean activate(KeyboardKeySpec spec) {
        switch (spec.action) {
            case CHARACTER:
                listener.insertText(spec.label);
                return true;
            case DELETE:
                return listener.deleteBackward();
            case SPACE:
                listener.insertText(" ");
                return true;
            case ENTER:
                listener.insertText("\n");
                return true;
            case NEXT_KEYBOARD:
                listener.switchToNextKeyboard();
                return true;
            case ALTERNATE_SYMBOLS:
                page = KeyboardSymbolLayout.Page.ALTERNATE;
                rebuild();
                return true;
            case NUMBER_SYMBOLS:
                page = KeyboardSymbolLayout.Page.PRIMARY;
                rebuild();
                return true;
            case RESTORE_FULL_KEYBOARD:
                setCompact(false);
                return true;
        }
        return false;
    }

    private void enterCompactMode() {
        if (page == KeyboardSymbolLayout.Page.PRIMARY && !compact) setCompact(true);
    }

    private void setCompact(boolean compact) {
        this.compact = compact;
        page = KeyboardSymbolLayout.Page.PRIMARY;
        preferences.edit().putBoolean(COMPACT_KEY, compact).apply();
        rebuild();
        requestLayout();
    }

    private CharSequence accessibilityLabel(KeyboardKeySpec spec) {
        switch (spec.action) {
            case DELETE: return getContext().getString(R.string.delete_key);
            case SPACE: return getContext().getString(R.string.space_key);
            case ENTER: return getContext().getString(R.string.enter_key);
            case NEXT_KEYBOARD: return getContext().getString(R.string.next_keyboard);
            case ALTERNATE_SYMBOLS: return getContext().getString(R.string.alternate_symbols);
            case NUMBER_SYMBOLS: return getContext().getString(R.string.number_symbols);
            case RESTORE_FULL_KEYBOARD: return getContext().getString(R.string.restore_full_keyboard);
            case CHARACTER:
            default: return spec.label;
        }
    }
}
