import Combine
import Foundation

@MainActor
final class KeyVoxSpeakIntroController: ObservableObject {
    @Published var isPresented: Bool

    private let defaults: UserDefaults
    private let forcePresentation: Bool
    private var pendingPresentationTask: Task<Void, Never>?

    private let presentationDelayNanoseconds: UInt64 = 1_500_000_000

    init(
        defaults: UserDefaults,
        forcePresentation: Bool = false
    ) {
        self.defaults = defaults
        self.forcePresentation = forcePresentation
        self.isPresented = false
    }

    func markDeferredUntilNextEligibleLaunch() {
        guard hasSeenIntro == false else { return }
        guard hasUsedKeyVoxSpeak == false else { return }
        defaults.set(true, forKey: UserDefaultsKeys.App.shouldShowKeyVoxSpeakIntroOnNextEligibleLaunch)
    }

    func handleAppDidBecomeActive(
        onboardingStore: OnboardingStore,
        isShowingReturnToHost: Bool
    ) {
        if forcePresentation {
            isPresented = true
            return
        }

        guard shouldShowOnNextEligibleLaunch else { return }
        guard isShowingReturnToHost == false else { return }
        guard onboardingStore.shouldShowOnboarding == false else { return }
        guard onboardingStore.hasCompletedOnboardingThisLaunch == false else { return }
        guard hasSeenIntro == false else { return }
        guard hasUsedKeyVoxSpeak == false else { return }
        guard pendingPresentationTask == nil else { return }

        pendingPresentationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.presentationDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            guard shouldShowOnNextEligibleLaunch else { return }
            guard hasSeenIntro == false else { return }
            guard hasUsedKeyVoxSpeak == false else { return }

            defaults.set(false, forKey: UserDefaultsKeys.App.shouldShowKeyVoxSpeakIntroOnNextEligibleLaunch)
            isPresented = true
            pendingPresentationTask = nil
        }
    }

    func schedulePresentationIfEligible() {
        if forcePresentation {
            isPresented = true
            return
        }

        guard shouldShowOnNextEligibleLaunch == false else { return }
        guard hasSeenIntro == false else { return }
        guard hasUsedKeyVoxSpeak == false else { return }
        guard isPresented == false else { return }
        guard pendingPresentationTask == nil else { return }

        pendingPresentationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.presentationDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            guard hasSeenIntro == false else { return }
            guard hasUsedKeyVoxSpeak == false else { return }

            isPresented = true
            pendingPresentationTask = nil
        }
    }

    func cancelPendingPresentation() {
        pendingPresentationTask?.cancel()
        pendingPresentationTask = nil
    }

    func markFeatureUsed() {
        cancelPendingPresentation()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasUsedKeyVoxSpeak)
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenKeyVoxSpeakIntro)
        isPresented = false
    }

    func dismiss() {
        cancelPendingPresentation()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenKeyVoxSpeakIntro)
        isPresented = false
    }

    private var hasSeenIntro: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.hasSeenKeyVoxSpeakIntro)
    }

    private var hasUsedKeyVoxSpeak: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.hasUsedKeyVoxSpeak)
    }

    private var shouldShowOnNextEligibleLaunch: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.shouldShowKeyVoxSpeakIntroOnNextEligibleLaunch)
    }
}
