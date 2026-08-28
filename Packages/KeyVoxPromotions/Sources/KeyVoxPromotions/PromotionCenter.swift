import Combine
import Foundation

@MainActor
public final class PromotionCenter: ObservableObject {
    @Published public private(set) var currentCampaign: PromotionCampaign?

    private let repository: PromotionManifestRepository
    private let stateStore: PromotionStateStore
    private let audience: PromotionAudience
    private let previewCampaignID: String?
    private let nowProvider: @Sendable () -> Date
    private var refreshTask: Task<Void, Never>?

    public init(
        repository: PromotionManifestRepository,
        stateStore: PromotionStateStore,
        audience: PromotionAudience,
        previewCampaignID: String? = nil,
        initialManifest: PromotionManifest? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.stateStore = stateStore
        self.audience = audience
        self.previewCampaignID = previewCampaignID
        self.nowProvider = nowProvider

        let initialSelection = initialManifest.map {
            PromotionSelector.select(
                manifest: $0,
                audience: audience,
                now: nowProvider(),
                previousState: stateStore.selectionState(),
                previewCampaignID: previewCampaignID
            )
        }
        currentCampaign = initialSelection?.campaign
        if previewCampaignID == nil {
            stateStore.setSelectionState(initialSelection?.state)
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    public func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            _ = try? await repository.loadManifest()
        }
    }
}
