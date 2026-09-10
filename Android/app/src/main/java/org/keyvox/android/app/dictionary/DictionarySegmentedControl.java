package org.keyvox.android.app.dictionary;

import android.content.Context;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.function.Consumer;
import org.keyvox.android.R;

/** Two-state dictionary ordering control matching the iOS segmented picker. */
final class DictionarySegmentedControl extends LinearLayout {
    private final TextView alphabetical;
    private final TextView recentlyAdded;
    private final Consumer<DictionarySortMode> selection;
    private DictionarySortMode selected = DictionarySortMode.ALPHABETICAL;

    DictionarySegmentedControl(Context context, Consumer<DictionarySortMode> selection) {
        super(context);
        this.selection = selection;
        setOrientation(HORIZONTAL);
        setPadding(dp(2), dp(2), dp(2), dp(2));
        setBackground(background(getColor(R.color.app_card_fill), dp(16), 0));

        alphabetical = segment(R.string.dictionary_sort_alphabetical, DictionarySortMode.ALPHABETICAL);
        recentlyAdded = segment(R.string.dictionary_sort_recent, DictionarySortMode.RECENTLY_ADDED);
        addView(alphabetical, new LayoutParams(0, dp(28), 1));
        addView(recentlyAdded, new LayoutParams(0, dp(28), 1));
        render();
    }

    void selectWithoutFeedback(DictionarySortMode mode) {
        selected = mode;
        render();
    }

    private TextView segment(int label, DictionarySortMode mode) {
        TextView view = new TextView(getContext());
        view.setText(label);
        view.setTextSize(13);
        view.setGravity(Gravity.CENTER);
        view.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL));
        view.setOnClickListener(ignored -> {
            if (selected == mode) return;
            selected = mode;
            performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK);
            render();
            selection.accept(mode);
        });
        return view;
    }

    private void render() {
        render(alphabetical, selected == DictionarySortMode.ALPHABETICAL);
        render(recentlyAdded, selected == DictionarySortMode.RECENTLY_ADDED);
    }

    private void render(TextView view, boolean isSelected) {
        view.setSelected(isSelected);
        view.setTextColor(isSelected ? 0xFF000000 : getColor(R.color.app_primary_text));
        view.setTypeface(Typeface.create("sans-serif", isSelected ? Typeface.BOLD : Typeface.NORMAL));
        view.setBackground(isSelected
            ? background(getColor(R.color.app_accent), dp(14), 0)
            : null);
    }

    private GradientDrawable background(int fill, float radius, int stroke) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(fill);
        drawable.setCornerRadius(radius);
        if (stroke != 0) drawable.setStroke(dp(1), stroke);
        return drawable;
    }

    private int getColor(int id) { return getResources().getColor(id, getContext().getTheme()); }
    private int dp(float value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
