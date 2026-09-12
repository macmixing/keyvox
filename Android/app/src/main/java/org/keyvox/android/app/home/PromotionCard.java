package org.keyvox.android.app.home;

import android.content.Context;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import org.keyvox.android.R;
import org.keyvox.android.app.promotion.PromotionCampaign;

/** Renders shared campaign content with Android-native actions. */
final class PromotionCard extends LinearLayout {
    PromotionCard(Context context, PromotionCampaign campaign) {
        super(context);
        setOrientation(VERTICAL);
        int padding = dimension(R.dimen.app_card_padding);
        setPadding(padding, padding, padding, padding);
        setBackgroundResource(R.drawable.app_promotion_background);

        LinearLayout header = new LinearLayout(context);
        header.setOrientation(HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        addView(header, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        header.addView(iconView(campaign), new LayoutParams(dp(32), dp(32)));

        TextView title = new TextView(context);
        title.setText(campaign.title);
        title.setTextColor(getResources().getColor(R.color.app_primary_text, context.getTheme()));
        title.setTextSize(18);
        title.setTypeface(getResources().getFont(R.font.kanit_medium));
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        titleParams.leftMargin = dp(12);
        header.addView(title, titleParams);

        if (campaign.sharingURL != null) {
            ImageButton share = new ImageButton(context);
            share.setImageResource(R.drawable.ic_share);
            share.setImageTintList(ColorStateList.valueOf(Color.WHITE));
            share.setBackgroundColor(Color.TRANSPARENT);
            share.setContentDescription(getResources().getString(R.string.share_campaign, campaign.title));
            share.setOnClickListener(view -> share(campaign));
            header.addView(share, new LayoutParams(dp(44), dp(44)));
        }

        TextView message = new TextView(context);
        message.setText(campaign.message);
        message.setTextColor(getResources().getColor(R.color.app_primary_text, context.getTheme()));
        message.setTextSize(15);
        message.setTypeface(getResources().getFont(R.font.kanit_light));
        LayoutParams messageParams = new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        messageParams.topMargin = dp(12);
        addView(message, messageParams);

        if (campaign.buttonTitle != null && campaign.actionURL != null) {
            Button action = new Button(context);
            action.setText(campaign.buttonTitle);
            action.setTextSize(14);
            action.setAllCaps(false);
            action.setGravity(Gravity.CENTER);
            action.setTypeface(getResources().getFont(R.font.kanit_medium), Typeface.NORMAL);
            action.setTextColor(Color.BLACK);
            action.setBackgroundResource(R.drawable.app_primary_button_background);
            action.setOnClickListener(view -> open(campaign.actionURL));
            LayoutParams actionParams = new LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dimension(R.dimen.app_regular_button_height)
            );
            actionParams.topMargin = dp(12);
            addView(action, actionParams);
        }
    }

    private View iconView(PromotionCampaign campaign) {
        FrameLayout container = new FrameLayout(getContext());
        container.setBackgroundResource(R.drawable.app_promotion_icon_background);

        ImageView icon = new ImageView(getContext());
        int iconSize;
        if ("appBundleIcon".equals(campaign.iconKind)) {
            icon.setImageResource(R.drawable.ic_keyvox_circle);
            icon.setImageTintList(ColorStateList.valueOf(Color.WHITE));
            iconSize = dp(20);
        } else {
            int resource = campaign.iconName == null ? 0 : getResources().getIdentifier(
                campaign.iconName,
                "drawable",
                getContext().getPackageName()
            );
            if (resource != 0) icon.setImageResource(resource);
            icon.setImageTintList(ColorStateList.valueOf(
                getResources().getColor(R.color.app_primary_action, getContext().getTheme())
            ));
            iconSize = dp(16);
        }
        FrameLayout.LayoutParams iconParams = new FrameLayout.LayoutParams(iconSize, iconSize, Gravity.CENTER);
        container.addView(icon, iconParams);
        return container;
    }

    private void open(String url) {
        getContext().startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
    }

    private void share(PromotionCampaign campaign) {
        String sharedText = campaign.message + "\n\n" + campaign.sharingURL;
        Intent intent = new Intent(Intent.ACTION_SEND)
            .setType("text/plain")
            .putExtra(Intent.EXTRA_TEXT, sharedText)
            .putExtra(Intent.EXTRA_SUBJECT,
                campaign.sharingTitle == null ? campaign.title : campaign.sharingTitle);
        getContext().startActivity(Intent.createChooser(intent, null));
    }

    private int dimension(int resource) {
        return getResources().getDimensionPixelSize(resource);
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
