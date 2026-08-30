import Combine
import Foundation
import KeyVoxCore

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

    @Published private(set) var hasCompletedLanguageSelection: Bool {
        didSet {
            defaults.set(
                hasCompletedLanguageSelection,
                forKey: UserDefaultsKeys.App.hasCompletedOnboardingLanguageSelection
            )
        }
    }

    @Published private(set) var onboardingDictationLanguage: DictationLanguage? {
        didSet {
            if let onboardingDictationLanguage {
                defaults.set(
                    onboardingDictationLanguage.rawValue,
                    forKey: UserDefaultsKeys.App.onboardingDictationLanguage
                )
            } else {
                defaults.removeObject(forKey: UserDefaultsKeys.App.onboardingDictationLanguage)
            }
        }
    }

    @Published private(set) var isForceOnboardingLaunch: Bool
    @Published private(set) var isForceDictationShortcutSetupLaunch: Bool
    @Published private(set) var hasPendingKeyboardTour: Bool {
        didSet {
            defaults.set(hasPendingKeyboardTour, forKey: UserDefaultsKeys.App.hasPendingKeyboardTour)
        }
    }
    @Published private(set) var hasPendingDictationShortcutSetup: Bool {
        didSet {
            defaults.set(
                hasPendingDictationShortcutSetup,
                forKey: UserDefaultsKeys.App.hasPendingDictationShortcutSetup
            )
        }
    }
    @Published private(set) var hasPassedWelcomeScreenThisLaunch: Bool
    @Published private(set) var hasPassedLanguageSelectionThisLaunch: Bool
    @Published private(set) var isPendingKeyboardTourRouteArmed: Bool
    @Published private(set) var isIgnoringPersistedPendingKeyboardTourThisLaunch: Bool
    @Published private(set) var hasCompletedOnboardingThisLaunch: Bool

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
            || isForceOnboardingLaunch
            || isForceDictationShortcutSetupLaunch
            || hasPendingKeyboardTour
            || hasPendingDictationShortcutSetup
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

    var shouldShowLanguageSelectionScreen: Bool {
        !hasPassedLanguageSelectionThisLaunch
            && (isForceOnboardingLaunch || !hasCompletedLanguageSelection)
    }

    var shouldShowDictationShortcutSetupScreen: Bool {
        (isForceDictationShortcutSetupLaunch || hasPendingDictationShortcutSetup)
            && shouldShowOnboarding
    }

    var shouldSuppressReturnToHostView: Bool {
        shouldShowOnboarding || hasCompletedOnboardingThisLaunch
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults, runtimeFlags: RuntimeFlags) {
        self.defaults = defaults
        let persistedPendingKeyboardTour = defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool ?? false
        let persistedPendingDictationShortcutSetup = defaults.object(
            forKey: UserDefaultsKeys.App.hasPendingDictationShortcutSetup
        ) as? Bool ?? false
        hasCompletedOnboarding = defaults.object(forKey: UserDefaultsKeys.App.hasCompletedOnboarding) as? Bool ?? false
        hasCompletedWelcomeScreen = defaults.object(forKey: UserDefaultsKeys.App.hasCompletedOnboardingWelcome) as? Bool ?? false
        hasCompletedLanguageSelection = defaults.object(
            forKey: UserDefaultsKeys.App.hasCompletedOnboardingLanguageSelection
        ) as? Bool ?? false
        onboardingDictationLanguage = defaults
            .string(forKey: UserDefaultsKeys.App.onboardingDictationLanguage)
            .map(DictationLanguage.init(rawValue:))
        isForceOnboardingLaunch = runtimeFlags.forceOnboarding
        isForceDictationShortcutSetupLaunch = runtimeFlags.forceDictationShortcutSetup
        hasPendingKeyboardTour = persistedPendingKeyboardTour
        hasPendingDictationShortcutSetup = persistedPendingDictationShortcutSetup
        hasPassedWelcomeScreenThisLaunch = false
        hasPassedLanguageSelectionThisLaunch = false
        isPendingKeyboardTourRouteArmed = persistedPendingKeyboardTour
        isIgnoringPersistedPendingKeyboardTourThisLaunch = runtimeFlags.forceOnboarding
        hasCompletedOnboardingThisLaunch = false
    }

    func completeOnboarding() {
        clearPendingKeyboardTour()
        clearPendingDictationShortcutSetup()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenDictationShortcutSetup)
        hasCompletedOnboarding = true
        isForceOnboardingLaunch = false
        isForceDictationShortcutSetupLaunch = false
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

    func clearPendingDictationShortcutSetup() {
        hasPendingDictationShortcutSetup = false
    }

    func completeWelcomeScreen() {
        hasCompletedWelcomeScreen = true
        hasPassedWelcomeScreenThisLaunch = true
    }

    func completeLanguageSelection(language: DictationLanguage) {
        onboardingDictationLanguage = language
        hasCompletedLanguageSelection = true
        hasPassedLanguageSelectionThisLaunch = true
    }

    func returnToLanguageSelection() {
        hasCompletedLanguageSelection = false
        hasPassedLanguageSelectionThisLaunch = false
    }

    func completeKeyboardTour() {
        clearPendingKeyboardTour()
        hasPendingDictationShortcutSetup = true
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

    func recordKeyboardTourHandoffIfReady(
        isModelReady: Bool,
        isMicrophonePermissionGranted: Bool,
        isKeyboardEnabledInSystemSettings: Bool
    ) {
        guard isModelReady,
              isMicrophonePermissionGranted,
              isKeyboardEnabledInSystemSettings else {
            return
        }

        recordPendingKeyboardTour()
        armPendingKeyboardTourRouteIfNeeded(
            isKeyboardEnabledInSystemSettings: isKeyboardEnabledInSystemSettings
        )
    }
}
