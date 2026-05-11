import Combine
import Foundation
import KeyVoxStyleRewrite

@MainActor
final class MacVibesReadinessPrewarmer {
    private static let readinessPrewarmStyle = StyleRewriteStyle.casual

    private let prewarm: (StyleRewriteStyle) -> Void
    private var hasPrewarmedCurrentReadyModel = false
    private var cancellables = Set<AnyCancellable>()

    init(
        installState: AnyPublisher<MacLocalRewriteModelInstallState, Never>,
        prewarm: @escaping (StyleRewriteStyle) -> Void
    ) {
        self.prewarm = prewarm

        installState
            .sink { [weak self] installState in
                self?.handle(installState: installState)
            }
            .store(in: &cancellables)
    }

    private func handle(installState: MacLocalRewriteModelInstallState) {
        guard case .ready = installState else {
            hasPrewarmedCurrentReadyModel = false
            return
        }

        guard !hasPrewarmedCurrentReadyModel else {
            return
        }

        hasPrewarmedCurrentReadyModel = true
        prewarm(Self.readinessPrewarmStyle)
    }
}
