import Foundation

public extension PromotionCenter {
    convenience init(
        platform: PromotionPlatform,
        appVersion: String,
        defaults: UserDefaults,
        usesBundledManifest: Bool,
        previewCampaignID: String?
    ) {
        let isPreview = usesBundledManifest || previewCampaignID != nil
        let stateStore = PromotionStateStore(
            defaults: defaults,
            namespace: isPreview
                ? PromotionDefaults.previewStateNamespace
                : PromotionDefaults.productionStateNamespace
        )
        let source: PromotionManifestSource = usesBundledManifest
            ? .bundled
            : .remote(PromotionDefaults.manifestURL)
        let repository = PromotionManifestRepository(
            source: source,
            stateStore: stateStore
        )
        let initialManifest = PromotionManifestRepository.startupManifest(
            source: source,
            stateStore: stateStore
        )
        self.init(
            repository: repository,
            stateStore: stateStore,
            audience: PromotionAudience(platform: platform, appVersion: appVersion),
            previewCampaignID: previewCampaignID,
            initialManifest: initialManifest
        )
    }
}
