import Combine
import Foundation

@MainActor
final class KeyVoxSpeakIntroController: ObservableObject {
    @Published var isPresented: Bool

    private let defaults: UserDefaults
    private let forcePresentation: Bool
    private var hasCountedEligibleOpenThisLaunch = false

    init(
        defaults: UserDefaults,
        forcePresentation: Bool = false
    ) {
        self.defaults = defaults
        self.forcePresentation = forcePresentation
        self.isPresented = false
    }

    func handleAppDidBecomeActive(onboardingStore: OnboardingStore) {
        if forcePresentation {
            isPresented = true
            return
        }

        guard onboardingStore.shouldShowOnboarding == false else { return }
        guard onboardingStore.hasCompletedOnboardingThisLaunch == false else { return }
        guard hasSeenIntro == false else { return }
        guard hasUsedKeyVoxSpeak == false else { return }
        guard hasCountedEligibleOpenThisLaunch == false else { return }

        let eligibleOpenCount = defaults.integer(forKey: UserDefaultsKeys.App.keyVoxSpeakEligibleOpenCount) + 1
        defaults.set(eligibleOpenCount, forKey: UserDefaultsKeys.App.keyVoxSpeakEligibleOpenCount)
        hasCountedEligibleOpenThisLaunch = true

        if eligibleOpenCount >= 3 {
            isPresented = true
        }
    }

    func markFeatureUsed() {
        defaults.set(true, forKey: UserDefaultsKeys.App.hasUsedKeyVoxSpeak)
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenKeyVoxSpeakIntro)
        isPresented = false
    }

    func dismiss() {
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenKeyVoxSpeakIntro)
        isPresented = false
    }

    private var hasSeenIntro: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.hasSeenKeyVoxSpeakIntro)
    }

    private var hasUsedKeyVoxSpeak: Bool {
        defaults.bool(forKey: UserDefaultsKeys.App.hasUsedKeyVoxSpeak)
    }
}
