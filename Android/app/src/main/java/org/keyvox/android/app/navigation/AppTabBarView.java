package org.keyvox.android.app.navigation;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.EnumMap;
import java.util.Map;
import java.util.function.Consumer;
import org.keyvox.android.R;

/** Renders and updates the four equal-width containing-app tab controls. */
final class AppTabBarView extends LinearLayout {
    private final Map<ContainingAppTab, LinearLayout> items = new EnumMap<>(ContainingAppTab.class);

    AppTabBarView(Context context, Consumer<ContainingAppTab> selection) {
        super(context);
        setOrientation(HORIZONTAL);
        setGravity(Gravity.CENTER);
        setBackgroundResource(R.drawable.app_tab_bar_background);
        setElevation(dp(8));

        for (ContainingAppTab tab : ContainingAppTab.values()) {
            LinearLayout item = createItem(tab);
            item.setOnClickListener(view -> selection.accept(tab));
            items.put(tab, item);
            addView(item, new LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1));
        }
    }

    void select(ContainingAppTab selectedTab) {
        for (Map.Entry<ContainingAppTab, LinearLayout> entry : items.entrySet()) {
            boolean selected = entry.getKey() == selectedTab;
            LinearLayout item = entry.getValue();
            item.setSelected(selected);
            item.getChildAt(0).setSelected(selected);
            item.getChildAt(1).setSelected(selected);
        }
    }

    private LinearLayout createItem(ContainingAppTab tab) {
        LinearLayout item = new LinearLayout(getContext());
        item.setOrientation(VERTICAL);
        item.setGravity(Gravity.CENTER);
        item.setPadding(0, dp(7), 0, dp(4));
        item.setClickable(true);
        item.setFocusable(true);
        item.setMinimumHeight(dp(48));
        item.setContentDescription(getContext().getString(tab.labelResource));
        item.setBackgroundResource(android.R.drawable.list_selector_background);

        ColorStateList tint = getResources().getColorStateList(R.color.app_tab_item_tint, getContext().getTheme());
        ImageView icon = new ImageView(getContext());
        icon.setImageResource(tab.iconResource);
        icon.setImageTintList(tint);
        icon.setDuplicateParentStateEnabled(true);
        item.addView(icon, new LayoutParams(dp(24), dp(24)));

        TextView label = new TextView(getContext());
        label.setText(tab.labelResource);
        label.setTextColor(tint);
        label.setTextSize(11);
        label.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL));
        label.setGravity(Gravity.CENTER);
        label.setDuplicateParentStateEnabled(true);
        LayoutParams labelParams = new LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        labelParams.topMargin = dp(2);
        item.addView(label, labelParams);
        return item;
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
