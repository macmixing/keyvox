import Foundation

public struct PromotionSelectionState: Codable, Equatable, Sendable {
    public let campaignID: String
    public let selectedAt: Date

    public init(campaignID: String, selectedAt: Date) {
        self.campaignID = campaignID
        self.selectedAt = selectedAt
    }
}

enum PromotionSelector {
    static func select(
        manifest: PromotionManifest,
        audience: PromotionAudience,
        now: Date,
        previousState: PromotionSelectionState?,
        previewCampaignID: String?
    ) -> (campaign: PromotionCampaign?, state: PromotionSelectionState?) {
        if let previewCampaignID {
            let preview = manifest.campaigns.first {
                $0.id == previewCampaignID
                    && PromotionEligibility.isEligible($0, audience: audience, now: now, ignoresAvailability: true)
            }
            return (preview, previousState)
        }

        let eligibleCampaigns = PromotionEligibility.eligibleCampaigns(
            in: manifest,
            audience: audience,
            now: now
        )
        guard let firstCampaign = eligibleCampaigns.first else {
            return (nil, nil)
        }

        guard let previousState,
              let previousIndex = eligibleCampaigns.firstIndex(where: { $0.id == previousState.campaignID }) else {
            let state = PromotionSelectionState(campaignID: firstCampaign.id, selectedAt: now)
            return (firstCampaign, state)
        }

        let previousCampaign = eligibleCampaigns[previousIndex]
        guard manifest.selection.mode == .rotating,
              let interval = manifest.selection.interval,
              now.timeIntervalSince(previousState.selectedAt) >= interval else {
            return (previousCampaign, previousState)
        }

        let nextIndex = eligibleCampaigns.index(after: previousIndex)
        let selectedCampaign = nextIndex < eligibleCampaigns.endIndex
            ? eligibleCampaigns[nextIndex]
            : firstCampaign
        let state = PromotionSelectionState(campaignID: selectedCampaign.id, selectedAt: now)
        return (selectedCampaign, state)
    }
}
