package org.keyvox.android.app.navigation;

import org.keyvox.android.R;

/** Ordered navigation destinations shared by the containing app's tab bar and swipe routing. */
public enum ContainingAppTab {
    HOME(R.string.tab_home, R.drawable.ic_home),
    DICTIONARY(R.string.tab_dictionary, R.drawable.ic_dictionary),
    STYLE(R.string.tab_style, R.drawable.ic_style),
    SETTINGS(R.string.tab_settings, R.drawable.ic_settings);

    public final int labelResource;
    public final int iconResource;

    ContainingAppTab(int labelResource, int iconResource) {
        this.labelResource = labelResource;
        this.iconResource = iconResource;
    }

    public ContainingAppTab previous() {
        int index = ordinal() - 1;
        return index >= 0 ? values()[index] : null;
    }

    public ContainingAppTab next() {
        int index = ordinal() + 1;
        return index < values().length ? values()[index] : null;
    }
}
