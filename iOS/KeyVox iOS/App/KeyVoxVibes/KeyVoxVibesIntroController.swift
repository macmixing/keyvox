import Combine
import Foundation

@MainActor
final class KeyVoxVibesIntroController: ObservableObject {
    @Published var isPresented: Bool
    @Published var introPresentation: KeyVoxVibesSheetView.IntroPresentation

    private let defaults: UserDefaults
    private let forcePresentation: Bool
    private let presentationDelayNanoseconds: UInt64
    private var pendingPresentationTask: Task<Void, Never>?

    init(
        defaults: UserDefaults,
        forcePresentation: Bool = false,
        presentationDelayNanoseconds: UInt64 = 1_500_000_000
    ) {
        self.defaults = defaults
        self.forcePresentation = forcePresentation
        self.presentationDelayNanoseconds = presentationDelayNanoseconds
        self.isPresented = false
        self.introPresentation = .full
    }

    func markDeferredUntilNextEligibleLaunch() {
        guard hasSeenIntro == false else { return }
        guard hasInteractedWithKeyVoxVibes == false else { return }
        defaults.set(true, forKey: UserDefaultsKeys.App.shouldShowKeyVoxVibesIntroOnNextEligibleLaunch)
    }

    func handleAppDidBecomeActive(
        onboardingStore: OnboardingStore,
        isShowingReturnToHost: Bool
    ) {
        if forcePresentation {
            introPresentation = .full
            isPresented = true
            return
        }

        guard shouldShowOnNextEligibleLaunch else { return }
        guard isShowingReturnToHost == false else { return }
        guard onboardingStore.shouldShowOnboarding == false else { return }
        guard onboardingStore.hasCompletedOnboardingThisLaunch == false else { return }
        guard hasSeenIntro == false else { return }
        guard hasInteractedWithKeyVoxVibes == false else { return }
        guard pendingPresentationTask == nil else { return }

        pendingPresentationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { pendingPresentationTask = nil }
            try? await Task.sleep(nanoseconds: self.presentationDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            guard shouldShowOnNextEligibleLaunch else { return }
            guard hasSeenIntro == false else { return }
            guard hasInteractedWithKeyVoxVibes == false else { return }

            defaults.set(false, forKey: UserDefaultsKeys.App.shouldShowKeyVoxVibesIntroOnNextEligibleLaunch)
            introPresentation = .full
            isPresented = true
        }
    }

    func schedulePresentationIfEligible() {
        if forcePresentation {
            introPresentation = .full
            isPresented = true
            return
        }

        guard isAutomaticPresentationEligible else { return }
        guard isPresented == false else { return }
        guard pendingPresentationTask == nil else { return }

        pendingPresentationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { pendingPresentationTask = nil }
            try? await Task.sleep(nanoseconds: self.presentationDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            guard hasSeenIntro == false else { return }
            guard hasInteractedWithKeyVoxVibes == false else { return }

            introPresentation = .full
            isPresented = true
        }
    }

    func present(introPresentation: KeyVoxVibesSheetView.IntroPresentation) {
        cancelPendingPresentation()
        self.introPresentation = introPresentation
        isPresented = true
    }

    func cancelPendingPresentation() {
        pendingPresentationTask?.cancel()
        pendingPresentationTask = nil
    }

    func dismiss() {
        cancelPendingPresentation()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenKeyVoxVibesIntro)
        isPresented = false
    }

    var isAutomaticPresentationEligible: Bool {
        shouldShowOnNextEligibleLaunch == false
            && hasSeenIntro == false
            && hasInteractedWithKeyVoxVibes == false
    }

    var wantsPresentationOnEligibleLaunch: Bool {
        (shouldShowOnNextEligibleLaunch || isAutomaticPresentationEligible)
            && hasSeenIntro == false
            && hasInteractedWithKeyVoxVibes == false
    }

    private var hasSeenIntro: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.hasSeenKeyVoxVibesIntro)
    }

    private var hasInteractedWithKeyVoxVibes: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.hasInteractedWithKeyVoxVibes)
    }

    private var shouldShowOnNextEligibleLaunch: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.shouldShowKeyVoxVibesIntroOnNextEligibleLaunch)
    }
}
