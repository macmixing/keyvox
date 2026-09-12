package org.keyvox.android.app.navigation;

import android.content.Context;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.EnumMap;
import java.util.Map;
import java.util.function.Function;
import org.keyvox.android.R;
import org.keyvox.android.app.presentation.AppLogoView;

/** Owns the containing app's selected tab and coordinates its chrome and content. */
public final class AppTabHostView extends LinearLayout {
    private final Function<ContainingAppTab, View> pageFactory;
    private final Map<ContainingAppTab, View> pages = new EnumMap<>(ContainingAppTab.class);
    private final LinearLayout homeTitle;
    private final TextView pageTitle;
    private final SwipeTabContentView content;
    private final AppTabBarView tabBar;
    private final AppTabHaptics haptics;
    private ContainingAppTab selectedTab = ContainingAppTab.HOME;

    public AppTabHostView(Context context, Function<ContainingAppTab, View> pageFactory) {
        super(context);
        this.pageFactory = pageFactory;
        haptics = new AppTabHaptics();
        setOrientation(VERTICAL);
        setBackgroundColor(getResources().getColor(R.color.app_screen_background, context.getTheme()));

        FrameLayout topBar = new FrameLayout(context);
        topBar.setBackgroundColor(getResources().getColor(R.color.app_chrome_background, context.getTheme()));
        addView(topBar, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)));

        homeTitle = new LinearLayout(context);
        homeTitle.setOrientation(HORIZONTAL);
        homeTitle.setGravity(Gravity.CENTER);
        AppLogoView logo = new AppLogoView(context);
        homeTitle.addView(logo, new LayoutParams(dp(44), dp(44)));
        TextView brand = new TextView(context);
        brand.setText(R.string.app_name);
        brand.setTextColor(getResources().getColor(R.color.app_primary_text, context.getTheme()));
        brand.setTextSize(28);
        brand.setTypeface(getResources().getFont(R.font.kanit_medium));
        LayoutParams brandParams = new LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        brandParams.leftMargin = dp(9);
        homeTitle.addView(brand, brandParams);
        topBar.addView(homeTitle, centeredWrapContent());

        pageTitle = new TextView(context);
        pageTitle.setTextColor(getResources().getColor(R.color.app_primary_text, context.getTheme()));
        pageTitle.setTextSize(17);
        pageTitle.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        pageTitle.setGravity(Gravity.CENTER);
        topBar.addView(pageTitle, centeredWrapContent());

        content = new SwipeTabContentView(context, this::selectPrevious, this::selectNext);
        addView(content, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        tabBar = new AppTabBarView(context, this::selectTabFromInteraction);
        addView(tabBar, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(64)));
        selectTab(ContainingAppTab.HOME);
    }

    public void selectTab(ContainingAppTab tab) {
        showTab(tab);
    }

    private void selectTabFromInteraction(ContainingAppTab tab) {
        if (tab == selectedTab) return;
        showTab(tab);
        haptics.selectionChanged(this);
    }

    private void showTab(ContainingAppTab tab) {
        selectedTab = tab;
        View page = pages.get(tab);
        if (page == null) {
            page = pageFactory.apply(tab);
            pages.put(tab, page);
        }
        content.removeAllViews();
        content.addView(page, new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ));
        homeTitle.setVisibility(tab == ContainingAppTab.HOME ? VISIBLE : GONE);
        pageTitle.setVisibility(tab == ContainingAppTab.HOME ? GONE : VISIBLE);
        pageTitle.setText(tab.labelResource);
        tabBar.select(tab);
    }

    public ContainingAppTab selectedTab() {
        return selectedTab;
    }

    public void setTabBarHiddenForModal(boolean hidden) {
        tabBar.setVisibility(hidden ? INVISIBLE : VISIBLE);
    }

    private void selectPrevious(boolean crossesNavigationThreshold) {
        ContainingAppTab previous = selectedTab.previous();
        if (previous == null) {
            haptics.blockedEdgeSwipe(this);
        } else if (crossesNavigationThreshold) {
            selectTabFromInteraction(previous);
        }
    }

    private void selectNext(boolean crossesNavigationThreshold) {
        ContainingAppTab next = selectedTab.next();
        if (next == null) {
            haptics.blockedEdgeSwipe(this);
        } else if (crossesNavigationThreshold) {
            selectTabFromInteraction(next);
        }
    }

    private FrameLayout.LayoutParams centeredWrapContent() {
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        );
        return params;
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
