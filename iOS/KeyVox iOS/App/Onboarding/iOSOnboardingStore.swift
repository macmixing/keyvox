import Combine
import Foundation

@MainActor
final class iOSOnboardingStore: ObservableObject {
    @Published private(set) var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: iOSUserDefaultsKeys.App.hasCompletedOnboarding)
        }
    }

    @Published private(set) var hasCompletedWelcomeScreen: Bool {
        didSet {
            defaults.set(hasCompletedWelcomeScreen, forKey: iOSUserDefaultsKeys.App.hasCompletedOnboardingWelcome)
        }
    }

    @Published private(set) var isForceOnboardingLaunch: Bool
    @Published private(set) var hasPendingKeyboardTour: Bool {
        didSet {
            defaults.set(hasPendingKeyboardTour, forKey: iOSUserDefaultsKeys.App.hasPendingKeyboardTour)
        }
    }
    @Published private(set) var hasPassedWelcomeScreenThisLaunch: Bool
    @Published private(set) var isPendingKeyboardTourRouteArmed: Bool
    @Published private(set) var isIgnoringPersistedPendingKeyboardTourThisLaunch: Bool

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding || isForceOnboardingLaunch || hasPendingKeyboardTour
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

    private let defaults: UserDefaults

    init(defaults: UserDefaults, runtimeFlags: iOSRuntimeFlags) {
        self.defaults = defaults
        let persistedPendingKeyboardTour = defaults.object(forKey: iOSUserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool ?? false
        hasCompletedOnboarding = defaults.object(forKey: iOSUserDefaultsKeys.App.hasCompletedOnboarding) as? Bool ?? false
        hasCompletedWelcomeScreen = defaults.object(forKey: iOSUserDefaultsKeys.App.hasCompletedOnboardingWelcome) as? Bool ?? false
        isForceOnboardingLaunch = runtimeFlags.forceOnboarding
        hasPendingKeyboardTour = persistedPendingKeyboardTour
        hasPassedWelcomeScreenThisLaunch = false
        isPendingKeyboardTourRouteArmed = persistedPendingKeyboardTour
        isIgnoringPersistedPendingKeyboardTourThisLaunch = runtimeFlags.forceOnboarding
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        isForceOnboardingLaunch = false
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
        clearPendingKeyboardTour()
        completeOnboarding()
    }

    func armPendingKeyboardTourRouteIfNeeded() {
        guard hasPendingKeyboardTour, !isIgnoringPersistedPendingKeyboardTourThisLaunch else { return }
        isPendingKeyboardTourRouteArmed = true
    }
}
