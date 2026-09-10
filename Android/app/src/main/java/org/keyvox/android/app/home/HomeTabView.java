package org.keyvox.android.app.home;

import android.content.Context;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import org.keyvox.android.R;
import org.keyvox.android.app.promotion.PromotionCampaign;

/** Composes the established Home sections without owning their state. */
public final class HomeTabView extends ScrollView {
    private final LinearLayout page;
    private final WeeklyWordStatsCard weeklyStats;
    private final LastTranscriptionCard lastTranscription;
    private PromotionCard promotion;
    private String campaignID;

    public HomeTabView(Context context) {
        super(context);
        setFillViewport(true);
        setClipToPadding(false);
        setVerticalScrollBarEnabled(false);
        setBackgroundColor(getResources().getColor(R.color.app_screen_background, context.getTheme()));

        page = new LinearLayout(context);
        page.setOrientation(LinearLayout.VERTICAL);
        int screenPadding = dimension(R.dimen.app_screen_padding);
        page.setPadding(screenPadding, dimension(R.dimen.app_tab_page_top_inset), screenPadding, screenPadding);
        addView(page, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        weeklyStats = new WeeklyWordStatsCard(context);
        page.addView(weeklyStats, sectionParams(false));

        lastTranscription = new LastTranscriptionCard(context);
        page.addView(lastTranscription, sectionParams(true));
    }

    public void render(int wordCount, String transcription, PromotionCampaign campaign) {
        weeklyStats.render(wordCount);
        lastTranscription.render(transcription);
        String nextCampaignID = campaign == null ? null : campaign.id;
        if (java.util.Objects.equals(campaignID, nextCampaignID)) return;
        campaignID = nextCampaignID;
        if (promotion != null) page.removeView(promotion);
        promotion = campaign == null ? null : new PromotionCard(getContext(), campaign);
        if (promotion != null) page.addView(promotion, sectionParams(true));
    }

    private LinearLayout.LayoutParams sectionParams(boolean hasTopMargin) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        if (hasTopMargin) params.topMargin = dimension(R.dimen.app_section_spacing);
        return params;
    }

    private int dimension(int resource) {
        return getResources().getDimensionPixelSize(resource);
    }
}
