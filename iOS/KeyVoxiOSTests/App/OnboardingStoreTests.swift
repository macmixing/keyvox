import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct OnboardingStoreTests {
    @Test func firstLaunchShowsOnboardingWhenCompletionStateIsMissing() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.shouldShowOnboarding)
        #expect(store.hasCompletedOnboarding == false)
        #expect(store.hasCompletedWelcomeScreen == false)
        #expect(store.isForceOnboardingLaunch == false)
        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.shouldShowWelcomeScreen)
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

    @Test func persistedPendingKeyboardTourStartsArmedOnInit() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasPendingKeyboardTour)

        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        #expect(store.hasPendingKeyboardTour)
        #expect(store.shouldShowKeyboardTourScreen)
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

    @Test func completingKeyboardTourClearsPendingFlagAndCompletesOnboarding() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()
        store.completeKeyboardTour()

        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.hasCompletedOnboarding)
        #expect(store.shouldShowOnboarding == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasCompletedOnboarding) as? Bool == true)
    }

    @Test func recordingPendingKeyboardTourDisarmsRouteUntilActivationCheckRuns() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()

        #expect(store.hasPendingKeyboardTour)
        #expect(store.shouldShowKeyboardTourScreen == false)
    }

    @Test func activationCheckClearsPendingKeyboardTourWhenKeyboardIsNotEnabled() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordPendingKeyboardTour()
        store.armPendingKeyboardTourRouteIfNeeded(isKeyboardEnabledInSystemSettings: false)

        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.shouldShowKeyboardTourScreen == false)
    }

    @Test func readyKeyboardTourHandoffRecordsAndArmsRoute() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordKeyboardTourHandoffIfReady(
            isModelReady: true,
            isMicrophonePermissionGranted: true,
            isKeyboardEnabledInSystemSettings: true
        )

        #expect(store.hasPendingKeyboardTour)
        #expect(store.shouldShowKeyboardTourScreen)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) as? Bool == true)
    }

    @Test func keyboardTourHandoffDoesNotRecordBeforeModelIsReady() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordKeyboardTourHandoffIfReady(
            isModelReady: false,
            isMicrophonePermissionGranted: true,
            isKeyboardEnabledInSystemSettings: true
        )

        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.shouldShowKeyboardTourScreen == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) == nil)
    }

    @Test func keyboardTourHandoffDoesNotRecordBeforeMicrophoneIsGranted() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordKeyboardTourHandoffIfReady(
            isModelReady: true,
            isMicrophonePermissionGranted: false,
            isKeyboardEnabledInSystemSettings: true
        )

        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.shouldShowKeyboardTourScreen == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) == nil)
    }

    @Test func keyboardTourHandoffDoesNotRecordBeforeKeyboardIsEnabled() {
        let defaults = makeDefaults()
        let store = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )

        store.recordKeyboardTourHandoffIfReady(
            isModelReady: true,
            isMicrophonePermissionGranted: true,
            isKeyboardEnabledInSystemSettings: false
        )

        #expect(store.hasPendingKeyboardTour == false)
        #expect(store.shouldShowKeyboardTourScreen == false)
        #expect(defaults.object(forKey: UserDefaultsKeys.App.hasPendingKeyboardTour) == nil)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OnboardingStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
