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

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding || isForceOnboardingLaunch
    }

    var shouldShowWelcomeScreen: Bool {
        !hasPassedWelcomeScreenThisLaunch && (isForceOnboardingLaunch || !hasCompletedWelcomeScreen)
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults, runtimeFlags: iOSRuntimeFlags) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.object(forKey: iOSUserDefaultsKeys.App.hasCompletedOnboarding) as? Bool ?? false
        hasCompletedWelcomeScreen = defaults.object(forKey: iOSUserDefaultsKeys.App.hasCompletedOnboardingWelcome) as? Bool ?? false
        isForceOnboardingLaunch = runtimeFlags.forceOnboarding
        hasPendingKeyboardTour = defaults.object(forKey: iOSUserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool ?? false
        hasPassedWelcomeScreenThisLaunch = false
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        isForceOnboardingLaunch = false
    }

    func recordPendingKeyboardTour() {
        hasPendingKeyboardTour = true
    }

    func clearPendingKeyboardTour() {
        hasPendingKeyboardTour = false
    }

    func completeWelcomeScreen() {
        hasCompletedWelcomeScreen = true
        hasPassedWelcomeScreenThisLaunch = true
    }
}
