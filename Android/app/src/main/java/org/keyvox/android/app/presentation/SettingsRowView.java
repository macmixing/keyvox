package org.keyvox.android.app.presentation;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.function.Consumer;
import org.keyvox.android.R;

/** Shared settings row with an icon, description, and trailing control. */
public final class SettingsRowView extends LinearLayout {
    private final AppToggleView toggle;

    public SettingsRowView(
        Context context,
        int iconResource,
        int titleResource,
        int descriptionResource,
        View trailingContent
    ) {
        super(context);
        toggle = trailingContent instanceof AppToggleView ? (AppToggleView) trailingContent : null;
        setOrientation(VERTICAL);

        LinearLayout header = new LinearLayout(context);
        header.setOrientation(HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        addView(header, new LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        ImageView icon = new ImageView(context);
        icon.setImageResource(iconResource);
        icon.setImageTintList(ColorStateList.valueOf(color(R.color.app_primary_action)));
        icon.setPadding(dp(8), dp(8), dp(8), dp(8));
        GradientDrawable iconBackground = new GradientDrawable();
        iconBackground.setShape(GradientDrawable.OVAL);
        iconBackground.setColor(withAlpha(color(R.color.app_accent), 0.4f));
        icon.setBackground(iconBackground);
        header.addView(icon, new LayoutParams(dp(32), dp(32)));

        TextView title = new TextView(context);
        title.setText(titleResource);
        title.setTextColor(color(R.color.app_primary_text));
        title.setTextSize(18);
        title.setTypeface(getResources().getFont(R.font.kanit_medium), Typeface.NORMAL);
        LayoutParams titleParams = new LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        titleParams.leftMargin = dp(12);
        header.addView(title, titleParams);

        LayoutParams trailingParams = new LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        trailingParams.leftMargin = dp(12);
        header.addView(trailingContent, trailingParams);

        TextView description = new TextView(context);
        description.setText(descriptionResource);
        description.setTextColor(color(R.color.app_secondary_text));
        description.setTextSize(15);
        description.setTypeface(getResources().getFont(R.font.kanit_light), Typeface.NORMAL);
        LayoutParams descriptionParams = new LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        descriptionParams.topMargin = dp(12);
        addView(description, descriptionParams);
    }

    public static SettingsRowView toggle(
        Context context,
        int iconResource,
        int titleResource,
        int descriptionResource,
        Consumer<Boolean> changed
    ) {
        AppToggleView toggle = new AppToggleView(context);
        toggle.setContentDescription(context.getString(titleResource));
        toggle.setOnCheckedChangeListener((button, isChecked) -> changed.accept(isChecked));
        return new SettingsRowView(
            context,
            iconResource,
            titleResource,
            descriptionResource,
            toggle
        );
    }

    public void setToggleChecked(boolean checked) {
        if (toggle != null) toggle.setChecked(checked);
    }

    private int color(int id) {
        return color(getContext(), id);
    }

    private static int color(Context context, int id) {
        return context.getResources().getColor(id, context.getTheme());
    }

    private int withAlpha(int color, float alpha) {
        return (Math.round(255 * alpha) << 24) | (color & 0x00FFFFFF);
    }

    private int dp(float value) {
        return dp(getContext(), value);
    }

    private static int dp(Context context, float value) {
        return Math.round(value * context.getResources().getDisplayMetrics().density);
    }
}
