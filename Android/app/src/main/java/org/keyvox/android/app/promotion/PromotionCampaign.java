package org.keyvox.android.app.promotion;

import org.json.JSONObject;

/** Immutable campaign content selected by the shared promotions package. */
public final class PromotionCampaign {
    public final String id;
    public final String iconKind;
    public final String iconName;
    public final String title;
    public final String message;
    public final String buttonTitle;
    public final String actionURL;
    public final String sharingURL;
    public final String sharingTitle;

    private PromotionCampaign(
        String id,
        String iconKind,
        String iconName,
        String title,
        String message,
        String buttonTitle,
        String actionURL,
        String sharingURL,
        String sharingTitle
    ) {
        this.id = id;
        this.iconKind = iconKind;
        this.iconName = iconName;
        this.title = title;
        this.message = message;
        this.buttonTitle = buttonTitle;
        this.actionURL = actionURL;
        this.sharingURL = sharingURL;
        this.sharingTitle = sharingTitle;
    }

    /** Decodes the campaign with the wording the engine chose for the app's language. */
    static PromotionCampaign decode(JSONObject value, JSONObject copy) throws Exception {
        JSONObject icon = value.getJSONObject("icon");
        JSONObject action = value.optJSONObject("action");
        JSONObject sharing = value.optJSONObject("sharing");
        return new PromotionCampaign(
            value.getString("id"),
            icon.getString("kind"),
            icon.optString("name", null),
            copy.getString("title"),
            copy.getString("message"),
            copy.optString("buttonTitle", null),
            action == null ? null : action.getString("url"),
            sharing == null ? null : sharing.getString("url"),
            sharing == null ? null : copy.optString("sharingTitle", null)
        );
    }
}
