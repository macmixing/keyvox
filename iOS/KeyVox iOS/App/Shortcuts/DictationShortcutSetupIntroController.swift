import Combine
import Foundation

@MainActor
final class DictationShortcutSetupIntroController: ObservableObject {
    @Published private(set) var isPresented = false
    private(set) var hasPresentedThisLaunch = false

    private let defaults: UserDefaults
    private let presentationDelayNanoseconds: UInt64
    private var pendingPresentationTask: Task<Void, Never>?

    init(
        defaults: UserDefaults,
        presentationDelayNanoseconds: UInt64 = 1_500_000_000
    ) {
        self.defaults = defaults
        self.presentationDelayNanoseconds = presentationDelayNanoseconds
    }

    var wantsPresentationOnEligibleLaunch: Bool {
        hasSeenIntro == false
    }

    func schedulePresentationIfEligible(onboardingStore: OnboardingStore) {
        guard onboardingStore.hasCompletedOnboarding else { return }
        guard onboardingStore.hasCompletedOnboardingThisLaunch == false else { return }
        guard hasSeenIntro == false else { return }
        guard isPresented == false else { return }
        guard pendingPresentationTask == nil else { return }

        pendingPresentationTask = Task { @MainActor [weak self, weak onboardingStore] in
            guard let self, let onboardingStore else { return }
            defer { pendingPresentationTask = nil }
            try? await Task.sleep(nanoseconds: presentationDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            guard onboardingStore.hasCompletedOnboarding else { return }
            guard onboardingStore.hasCompletedOnboardingThisLaunch == false else { return }
            guard hasSeenIntro == false else { return }

            hasPresentedThisLaunch = true
            isPresented = true
        }
    }

    func markHandled() {
        cancelPendingPresentation()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenDictationShortcutSetup)
        isPresented = false
    }

    func cancelPendingPresentation() {
        pendingPresentationTask?.cancel()
        pendingPresentationTask = nil
    }

    private var hasSeenIntro: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.hasSeenDictationShortcutSetup)
    }
}
