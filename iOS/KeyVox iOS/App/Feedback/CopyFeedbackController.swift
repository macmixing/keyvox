import Combine
import SwiftUI
import UIKit

@MainActor
final class CopyFeedbackController: ObservableObject {
    @Published private(set) var didCopy = false

    private var resetTask: Task<Void, Never>?

    deinit {
        resetTask?.cancel()
    }

    func copy(_ text: String, appHaptics: AppHapticsEmitting) {
        UIPasteboard.general.string = text
        appHaptics.success()
        didCopy = true

        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard Task.isCancelled == false else { return }
            didCopy = false
        }
    }
}
