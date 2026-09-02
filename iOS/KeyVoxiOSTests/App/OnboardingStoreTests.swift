import Foundation
import KeyVoxCore
import Testing
@testable import KeyVox_iOS

@MainActor
struct OnboardingStoreTests {
    @Test func freshDictionaryInstallOverrideUsesDebugEnvironmentFlag() {
        let disabled = RuntimeFlags(environment: [:])
        let enabled = RuntimeFlags(environment: [
            RuntimeFlags.forceFreshDictionaryInstallEnvironmentKey: "1",
        ])

        #expect(disabled.forceFreshDictionaryInstall == false)
        #if DEBUG
        #expect(enabled.forceFreshDictionaryInstall)
        #else
        #expect(enabled.forceFreshDictionaryInstall == false)
        #endif
    }

    @Test func firstLaunchShowsOnboardingWhenCompletionStateIsMissing() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.shouldShowOnboarding)
        #expect(store.hasCompletedOnboarding == false)
        #expect(store.hasCompletedWelcomeScreen == false)
        #expect(store.hasCompletedLanguageSelection == false)
        #expect(store.isForceOnboardingLaunch == false)
        #expect(store.isForceDictationShortcutSetupLaunch == false)
        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.hasPendingDictationShortcutSetup == false)
        #expect(store.shouldShowWelcomeScreen)
        #expect(store.shouldShowLanguageSelectionScreen)
        #expect(store.shouldShowKeyboardTourScreen == false)
    }

    @Test func completedOnboardingHidesFlowWhenForceFlagIsOff() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasCompletedOnboarding)

        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.shouldShowOnboarding == false)
        #expect(store.hasCompletedOnboarding)
        #expect(store.shouldShowWelcomeScreen)
    }

    @Test func completingOnboardingPersistsCompletedState() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.completeOnboarding()

        #expect(store.shouldShowOnboarding == false)
        #expect(store.hasCompletedOnboarding)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasCompletedOnboarding) as? Bool == true)
    }

    @Test func completingWelcomeScreenPersistsAndSkipsWelcomeWhenForceFlagIsOff() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.completeWelcomeScreen()

        let restoredStore = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.hasCompletedWelcomeScreen)
        #expect(store.shouldShowWelcomeScreen == false)
        #expect(restoredStore.hasCompletedWelcomeScreen)
        #expect(restoredStore.shouldShowWelcomeScreen == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasCompletedOnboardingWelcome) as? Bool == true)
    }

    @Test func recordingPendingKeyboardTourPersistsFlagAcrossLaunches() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()

        let restoredStore = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.hasPendingKeyboardTour)
        #expect(restoredStore.hasPendingKeyboardTour)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool == true)
    }

    @Test func completingLanguageSelectionPersistsTheLanguageAndAdvancesTheFlow() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        let selectedLanguage = DictationLanguage(rawValue: "en")
        store.completeLanguageSelection(language: selectedLanguage)

        let restoredStore = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.shouldShowLanguageSelectionScreen == false)
        #expect(restoredStore.hasCompletedLanguageSelection)
        #expect(restoredStore.onboardingDictationLanguage == selectedLanguage)
        #expect(defaults.string(forKey: UserDefaultsKeys.App.onboardingDictationLanguage) == "en")
    }

    @Test func returningToLanguageSelectionMakesTheStepVisibleAndDurable() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )
        store.completeLanguageSelection(language: DictationLanguage(rawValue: "es"))

        store.returnToLanguageSelection()

        let restoredStore = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.shouldShowLanguageSelectionScreen)
        #expect(restoredStore.shouldShowLanguageSelectionScreen)
        #expect(restoredStore.onboardingDictationLanguage == DictationLanguage(rawValue: "es"))
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasCompletedOnboardingLanguageSelection) as? Bool == false)
    }

    @Test func persistedPendingKeyboardTourReturnsToKeyboardSetupUntilActivationCheck() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasPendingKeyboardTour)

        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.hasPendingKeyboardTour)
        #expect(store.shouldShowKeyboardSetupScreen)
        #expect(store.shouldShowKeyboardTourScreen == false)
    }

    @Test func clearingPendingKeyboardTourResetsPersistedFlag() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasPendingKeyboardTour)

        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.clearPendingKeyboardTour()

        #expect(store.hasPendingKeyboardTour == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool == false)
    }

    @Test func completingKeyboardTourCompletesOnboarding() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()
        store.completeKeyboardTour()

        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.hasPendingDictationShortcutSetup == false)
        #expect(store.hasCompletedOnboarding)
        #expect(store.shouldShowOnboarding == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingDictationShortcutSetup) as? Bool == false)
        #expect(defaults.bool(forKey: UserDefaultsKeys.App.hasCompletedOnboarding))
    }

    @Test func shortcutSetupForceFlagStartsAtShortcutIntroAndContinuesToKeyboardSetup() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasCompletedOnboarding)
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [
                RuntimeFlags.forceDictationShortcutSetupEnvironmentKey: "1"
            ])
        )

        #expect(store.shouldShowOnboarding)
        #expect(store.isForceDictationShortcutSetupLaunch)
        #expect(store.shouldShowDictationShortcutSetupScreen)
        #expect(store.hasPendingDictationShortcutSetup == false)

        store.continueToKeyboardSetup()

        #expect(store.isForceDictationShortcutSetupLaunch == false)
        #expect(store.shouldShowWelcomeScreen == false)
        #expect(store.shouldShowLanguageSelectionScreen == false)
        #expect(store.shouldShowKeyboardSetupScreen)
    }

    @Test func completingOnboardingClearsShortcutSetupAndMarksItsIntroductionSeen() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )
        store.beginDictationShortcutSetup()

        store.completeOnboarding()

        #expect(store.hasPendingDictationShortcutSetup == false)
        #expect(store.hasCompletedOnboarding)
        #expect(store.shouldShowOnboarding == false)
        #expect(defaults.bool(forKey: UserDefaultsKeys.App.hasSeenDictationShortcutSetup))
    }

    @Test func recordingPendingKeyboardTourDisarmsRouteUntilActivationCheckRuns() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()

        #expect(store.hasPendingKeyboardTour)
        #expect(store.shouldShowKeyboardSetupScreen)
        #expect(store.shouldShowKeyboardTourScreen == false)
    }

    @Test func activationCheckKeepsKeyboardSetupVisibleWhenKeyboardIsNotEnabled() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()
        store.armPendingKeyboardTourRouteIfNeeded(isKeyboardEnabledInSystemSettings: false)

        #expect(store.hasPendingKeyboardTour)
        #expect(store.shouldShowKeyboardSetupScreen)
        #expect(store.shouldShowKeyboardTourScreen == false)
    }

    @Test func activationCheckAdvancesFromKeyboardSetupWhenKeyboardIsEnabled() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()
        store.armPendingKeyboardTourRouteIfNeeded(isKeyboardEnabledInSystemSettings: true)

        #expect(store.hasPendingKeyboardTour)
        #expect(store.shouldShowKeyboardSetupScreen == false)
        #expect(store.shouldShowKeyboardTourScreen)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool == true)
    }

    @Test func beginningShortcutSetupClearsKeyboardSetupAndShowsShortcutFlow() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()
        store.beginDictationShortcutSetup()

        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.hasPendingDictationShortcutSetup)
        #expect(store.shouldShowDictationShortcutSetupScreen)
    }

    @Test func continuingFromShortcutSetupShowsKeyboardSetup() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.beginDictationShortcutSetup()
        store.continueToKeyboardSetup()

        #expect(store.hasPendingDictationShortcutSetup == false)
        #expect(store.hasPendingKeyboardTour)
        #expect(store.shouldShowKeyboardSetupScreen)
        #expect(store.shouldShowKeyboardTourScreen == false)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OnboardingStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
