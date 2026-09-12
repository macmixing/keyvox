import Foundation
import KeyVoxPromotions

/// Owns shared campaign selection for the Android process; Java only renders its output.
@MainActor
final class AndroidPromotionCoordinator {
    static var shared: AndroidPromotionCoordinator?

    private let center: PromotionCenter

    static func install(resources: URL, appVersion: String) throws {
        try PromotionResources.configure(
            bundleURL: resources.appendingPathComponent("KeyVoxPromotions_KeyVoxPromotions.resources")
        )
        guard shared == nil else { return }
        shared = AndroidPromotionCoordinator(
            appVersion: appVersion,
            usesBundledManifest: false,
            previewCampaignID: nil
        )
    }

    static func configurePreview(
        appVersion: String,
        usesBundledManifest: Bool,
        previewCampaignID: String?
    ) {
        shared = AndroidPromotionCoordinator(
            appVersion: appVersion,
            usesBundledManifest: usesBundledManifest,
            previewCampaignID: previewCampaignID
        )
    }

    private init(
        appVersion: String,
        usesBundledManifest: Bool,
        previewCampaignID: String?
    ) {
        center = PromotionCenter(
            platform: .android,
            appVersion: appVersion,
            defaults: .standard,
            usesBundledManifest: usesBundledManifest,
            previewCampaignID: previewCampaignID
        )
        publishCurrentCampaign()
    }

    func refresh() {
        center.refresh()
    }

    private func publishCurrentCampaign() {
        EngineEvent(kind: .promotionConfigured, campaign: center.currentCampaign).send()
    }
}
