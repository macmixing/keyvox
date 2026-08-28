import Foundation

public struct PromotionAudience: Equatable, Sendable {
    public let platform: PromotionPlatform
    public let appVersion: String

    public init(platform: PromotionPlatform, appVersion: String) {
        self.platform = platform
        self.appVersion = appVersion
    }
}

enum PromotionEligibility {
    static func eligibleCampaigns(
        in manifest: PromotionManifest,
        audience: PromotionAudience,
        now: Date
    ) -> [PromotionCampaign] {
        manifest.campaigns.filter { isEligible($0, audience: audience, now: now) }
    }

    static func isEligible(
        _ campaign: PromotionCampaign,
        audience: PromotionAudience,
        now: Date,
        ignoresAvailability: Bool = false
    ) -> Bool {
        guard let target = campaign.targets.first(where: { $0.platform == audience.platform }) else {
            return false
        }

        if ignoresAvailability {
            return true
        }

        if let startsAt = campaign.startsAt, now < startsAt {
            return false
        }
        if let endsAt = campaign.endsAt, now >= endsAt {
            return false
        }
        guard let minimumAppVersion = target.minimumAppVersion else {
            return true
        }
        guard let currentVersion = PromotionVersion(audience.appVersion),
              let minimumVersion = PromotionVersion(minimumAppVersion) else {
            return false
        }
        return currentVersion >= minimumVersion
    }
}
