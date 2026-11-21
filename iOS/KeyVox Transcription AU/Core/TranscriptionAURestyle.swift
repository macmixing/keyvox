import Foundation

/// Runs the keyboard's restyle of an inserted dictation with the extension's Vibes model, the
/// way the containing app answers it when its session is running. A new restyle replaces one
/// still running.
@MainActor
final class TranscriptionAURestyle {
    private let coordinator: StyleRewritePipelineCoordinator
    private var task: Task<Void, Never>?

    /// The finished restyle, until the next one begins.
    private(set) var response: KeyVoxStyleRewriteIPCResponse?

    init(coordinator: StyleRewritePipelineCoordinator) {
        self.coordinator = coordinator
    }

    func begin(_ request: KeyVoxStyleRewriteIPCRequest) {
        cancel()
        task = Task { [coordinator] in
            let response = await coordinator.keyboardStyleRewriteResponse(for: request)
            guard !Task.isCancelled else { return }
            self.response = response
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        response = nil
    }
}
