import Combine
import Foundation

@MainActor
final class MacVibesIntroController: ObservableObject {
    static let shared = MacVibesIntroController()
    static let forceIntroEnvironmentKey = "KEYVOX_FORCE_KEYVOX_VIBES_INTRO"

    private let defaults: UserDefaults
    private let forcePresentation: Bool
    private let presentationDelayNanoseconds: UInt64
    private var pendingPresentationTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        presentationDelayNanoseconds: UInt64 = 1_500_000_000
    ) {
        self.defaults = defaults
        self.forcePresentation = Self.isEnabled(
            environmentValue: environment[Self.forceIntroEnvironmentKey]
        )
        self.presentationDelayNanoseconds = presentationDelayNanoseconds
    }

    func scheduleColdLaunchPresentationIfNeeded(
        hasCompletedOnboarding: Bool,
        present: @escaping @MainActor () -> Void
    ) {
        guard hasCompletedOnboarding else { return }
        guard forcePresentation || hasSeenIntro == false else { return }
        guard pendingPresentationTask == nil else { return }

        pendingPresentationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { pendingPresentationTask = nil }
            try? await Task.sleep(nanoseconds: presentationDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            guard forcePresentation || hasSeenIntro == false else { return }

            if forcePresentation == false {
                markSeen()
            }
            present()
        }
    }

    func cancelPendingPresentation() {
        pendingPresentationTask?.cancel()
        pendingPresentationTask = nil
    }

    func markSeen() {
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenKeyVoxVibesIntro)
    }

    var shouldForcePresentation: Bool {
        forcePresentation
    }

    var hasSeenIntro: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.hasSeenKeyVoxVibesIntro)
    }

    private static func isEnabled(environmentValue: String?) -> Bool {
        let normalizedValue = environmentValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return normalizedValue == "1"
            || normalizedValue == "true"
            || normalizedValue == "yes"
    }
}
