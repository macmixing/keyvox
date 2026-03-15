import Combine
import Foundation

@MainActor
final class iOSOnboardingStore: ObservableObject {
    @Published private(set) var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: iOSUserDefaultsKeys.App.hasCompletedOnboarding)
        }
    }

    @Published private(set) var isForceOnboardingLaunch: Bool
    @Published private(set) var hasPendingKeyboardTour: Bool {
        didSet {
            defaults.set(hasPendingKeyboardTour, forKey: iOSUserDefaultsKeys.App.hasPendingKeyboardTour)
        }
    }

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding || isForceOnboardingLaunch
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults, runtimeFlags: iOSRuntimeFlags) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.object(forKey: iOSUserDefaultsKeys.App.hasCompletedOnboarding) as? Bool ?? false
        isForceOnboardingLaunch = runtimeFlags.forceOnboarding
        hasPendingKeyboardTour = defaults.object(forKey: iOSUserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool ?? false
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
}
