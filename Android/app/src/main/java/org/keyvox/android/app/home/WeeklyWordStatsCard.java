package org.keyvox.android.app.home;

import android.content.Context;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.text.NumberFormat;
import org.keyvox.android.R;

/** Renders the iOS-equivalent weekly spoken-word summary. */
final class WeeklyWordStatsCard extends LinearLayout {
    private final TextView count;

    WeeklyWordStatsCard(Context context) {
        super(context);
        setOrientation(VERTICAL);
        setGravity(Gravity.CENTER_HORIZONTAL);
        int padding = dimension(R.dimen.app_card_padding);
        setPadding(padding, 0, padding, padding);
        setBackgroundResource(R.drawable.app_card_background);

        count = new TextView(context);
        count.setTextColor(getResources().getColor(R.color.app_primary_action, context.getTheme()));
        count.setTextSize(65);
        count.setGravity(Gravity.CENTER);
        count.setTypeface(getResources().getFont(R.font.kanit_medium), Typeface.BOLD);
        addView(count, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView label = new TextView(context);
        label.setText(R.string.home_words_this_week);
        label.setTextColor(getResources().getColor(R.color.app_primary_text, context.getTheme()));
        label.setTextSize(20);
        label.setGravity(Gravity.CENTER);
        label.setTypeface(getResources().getFont(R.font.kanit_medium), Typeface.BOLD);
        LayoutParams labelParams = new LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        labelParams.topMargin = -dp(14);
        addView(label, labelParams);
    }

    void render(int wordCount) {
        count.setText(NumberFormat.getIntegerInstance().format(wordCount));
    }

    private int dimension(int resource) {
        return getResources().getDimensionPixelSize(resource);
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
