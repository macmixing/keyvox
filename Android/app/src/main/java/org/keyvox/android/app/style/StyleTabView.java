package org.keyvox.android.app.style;

import android.content.Context;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import org.keyvox.android.R;
import org.keyvox.android.app.AppSettingsStore;
import org.keyvox.android.app.presentation.AppCardView;
import org.keyvox.android.app.presentation.SettingsRowView;

/** Composes the Android-supported Style settings in iOS order. */
public final class StyleTabView extends ScrollView {
    private final AppSettingsStore settingsStore;
    private final SettingsRowView listsRow;
    private final SettingsRowView paragraphsRow;
    private final Runnable changed = this::render;

    public StyleTabView(Context context, AppSettingsStore settingsStore) {
        super(context);
        this.settingsStore = settingsStore;
        setFillViewport(true);
        setClipToPadding(false);
        setVerticalScrollBarEnabled(false);
        setBackgroundColor(color(R.color.app_screen_background));

        LinearLayout page = new LinearLayout(context);
        page.setOrientation(LinearLayout.VERTICAL);
        int screenPadding = dimension(R.dimen.app_screen_padding);
        page.setPadding(
            screenPadding,
            dimension(R.dimen.app_tab_page_top_inset),
            screenPadding,
            screenPadding
        );
        addView(page, new LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        listsRow = SettingsRowView.toggle(
            context,
            R.drawable.ic_numbered_list,
            R.string.style_lists_title,
            R.string.style_lists_description,
            settingsStore::setListFormattingEnabled
        );
        page.addView(card(context, listsRow), cardParams(false));

        paragraphsRow = SettingsRowView.toggle(
            context,
            R.drawable.ic_paragraphs,
            R.string.style_paragraphs_title,
            R.string.style_paragraphs_description,
            settingsStore::setAutoParagraphsEnabled
        );
        page.addView(card(context, paragraphsRow), cardParams(true));
    }

    @Override protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        settingsStore.observe(changed);
    }

    @Override protected void onDetachedFromWindow() {
        settingsStore.removeObserver(changed);
        super.onDetachedFromWindow();
    }

    private void render() {
        listsRow.setToggleChecked(settingsStore.listFormattingEnabled());
        paragraphsRow.setToggleChecked(settingsStore.autoParagraphsEnabled());
    }

    private AppCardView card(Context context, SettingsRowView row) {
        AppCardView card = new AppCardView(context);
        card.addView(row, new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        return card;
    }

    private LinearLayout.LayoutParams cardParams(boolean hasTopMargin) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        if (hasTopMargin) params.topMargin = dimension(R.dimen.app_section_spacing);
        return params;
    }

    private int dimension(int id) {
        return getResources().getDimensionPixelSize(id);
    }

    private int color(int id) {
        return getResources().getColor(id, getContext().getTheme());
    }
}
