package org.keyvox.android.app.promotion;

import java.util.ArrayList;
import java.util.List;
import org.json.JSONObject;
import org.keyvox.android.engine.NativeEngine;

/** Owns the campaign currently visible for this Android process launch. */
public final class PromotionSession {
    private final List<Runnable> observers = new ArrayList<>();
    private PreviewRequest pendingPreview;
    private boolean engineReady;
    private PromotionCampaign currentCampaign;

    public PromotionCampaign currentCampaign() { return currentCampaign; }

    public void observe(Runnable observer) {
        observers.add(observer);
        observer.run();
    }

    public void removeObserver(Runnable observer) { observers.remove(observer); }

    public void receive(String json) {
        try {
            JSONObject event = new JSONObject(json);
            if (!"promotionConfigured".equals(event.optString("kind"))) return;
            engineReady = true;
            if (pendingPreview != null) {
                PreviewRequest preview = pendingPreview;
                pendingPreview = null;
                NativeEngine.configurePromotions(
                    preview.appVersion,
                    preview.usesBundledManifest,
                    preview.campaignID
                );
                return;
            }
            JSONObject campaign = event.optJSONObject("campaign");
            currentCampaign = campaign == null ? null : PromotionCampaign.decode(campaign);
            publish();
        } catch (Exception ignored) {
            currentCampaign = null;
            publish();
        }
    }

    public void configurePreview(String appVersion, boolean usesBundledManifest, String campaignID) {
        if (engineReady) {
            NativeEngine.configurePromotions(appVersion, usesBundledManifest, campaignID);
        } else {
            pendingPreview = new PreviewRequest(appVersion, usesBundledManifest, campaignID);
        }
    }

    public void refresh() { NativeEngine.refreshPromotions(); }

    private void publish() {
        for (Runnable observer : new ArrayList<>(observers)) observer.run();
    }

    private static final class PreviewRequest {
        final String appVersion;
        final boolean usesBundledManifest;
        final String campaignID;

        PreviewRequest(String appVersion, boolean usesBundledManifest, String campaignID) {
            this.appVersion = appVersion;
            this.usesBundledManifest = usesBundledManifest;
            this.campaignID = campaignID;
        }
    }
}
