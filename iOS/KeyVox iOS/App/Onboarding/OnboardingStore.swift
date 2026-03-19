import Combine
import Foundation

@MainActor
final class OnboardingStore: ObservableObject {
    @Published private(set) var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: UserDefaultsKeys.App.hasCompletedOnboarding)
        }
    }

    @Published private(set) var hasCompletedWelcomeScreen: Bool {
        didSet {
            defaults.set(hasCompletedWelcomeScreen, forKey: UserDefaultsKeys.App.hasCompletedOnboardingWelcome)
        }
    }

    @Published private(set) var isForceOnboardingLaunch: Bool
    @Published private(set) var hasPendingKeyboardTour: Bool {
        didSet {
            defaults.set(hasPendingKeyboardTour, forKey: UserDefaultsKeys.App.hasPendingKeyboardTour)
        }
    }
    @Published private(set) var hasPassedWelcomeScreenThisLaunch: Bool
    @Published private(set) var isPendingKeyboardTourRouteArmed: Bool
    @Published private(set) var isIgnoringPersistedPendingKeyboardTourThisLaunch: Bool
    @Published private(set) var hasCompletedOnboardingThisLaunch: Bool

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
            || isForceOnboardingLaunch
            || hasPendingKeyboardTour
    }

    var shouldShowWelcomeScreen: Bool {
        !hasPassedWelcomeScreenThisLaunch && (isForceOnboardingLaunch || !hasCompletedWelcomeScreen)
    }

    var shouldShowKeyboardTourScreen: Bool {
        hasPendingKeyboardTour
            && isPendingKeyboardTourRouteArmed
            && !isIgnoringPersistedPendingKeyboardTourThisLaunch
            && shouldShowOnboarding
    }

    var shouldSuppressReturnToHostView: Bool {
        shouldShowOnboarding || hasCompletedOnboardingThisLaunch
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults, runtimeFlags: RuntimeFlags) {
        self.defaults = defaults
        let persistedPendingKeyboardTour = defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool ?? false
        hasCompletedOnboarding = defaults.object(forKey: UserDefaultsKeys.App.hasCompletedOnboarding) as? Bool ?? false
        hasCompletedWelcomeScreen = defaults.object(forKey: UserDefaultsKeys.App.hasCompletedOnboardingWelcome) as? Bool ?? false
        isForceOnboardingLaunch = runtimeFlags.forceOnboarding
        hasPendingKeyboardTour = persistedPendingKeyboardTour
        hasPassedWelcomeScreenThisLaunch = false
        isPendingKeyboardTourRouteArmed = persistedPendingKeyboardTour
        isIgnoringPersistedPendingKeyboardTourThisLaunch = runtimeFlags.forceOnboarding
        hasCompletedOnboardingThisLaunch = false
    }

    func completeOnboarding() {
        clearPendingKeyboardTour()
        hasCompletedOnboarding = true
        isForceOnboardingLaunch = false
        hasCompletedOnboardingThisLaunch = true
    }

    func recordPendingKeyboardTour() {
        hasPendingKeyboardTour = true
        isPendingKeyboardTourRouteArmed = false
        isIgnoringPersistedPendingKeyboardTourThisLaunch = false
    }

    func clearPendingKeyboardTour() {
        hasPendingKeyboardTour = false
        isPendingKeyboardTourRouteArmed = false
        isIgnoringPersistedPendingKeyboardTourThisLaunch = false
    }

    func completeWelcomeScreen() {
        hasCompletedWelcomeScreen = true
        hasPassedWelcomeScreenThisLaunch = true
    }

    func completeKeyboardTour() {
        completeOnboarding()
    }

    func handleAppDidEnterBackground() {
        hasCompletedOnboardingThisLaunch = false
    }

    func armPendingKeyboardTourRouteIfNeeded(isKeyboardEnabledInSystemSettings: Bool) {
        guard hasPendingKeyboardTour, !isIgnoringPersistedPendingKeyboardTourThisLaunch else { return }

        guard isKeyboardEnabledInSystemSettings else {
            clearPendingKeyboardTour()
            return
        }

        isPendingKeyboardTourRouteArmed = true
    }
}
