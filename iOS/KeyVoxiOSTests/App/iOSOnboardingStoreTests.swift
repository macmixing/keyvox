import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSOnboardingStoreTests {
    @Test func firstLaunchShowsOnboardingWhenCompletionStateIsMissing() {
        let defaults = makeDefaults()
        let store = iOSOnboardingStore(
            defaults: defaults,
            runtimeFlags: iOSRuntimeFlags(environment: [:])
        )

        #expect(store.shouldShowOnboarding)
        #expect(store.hasCompletedOnboarding == false)
        #expect(store.isForceOnboardingLaunch == false)
    }

    @Test func completedOnboardingHidesFlowWhenForceFlagIsOff() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: iOSUserDefaultsKeys.App.hasCompletedOnboarding)

        let store = iOSOnboardingStore(
            defaults: defaults,
            runtimeFlags: iOSRuntimeFlags(environment: [:])
        )

        #expect(store.shouldShowOnboarding == false)
        #expect(store.hasCompletedOnboarding)
    }

    @Test func forceFlagShowsOnboardingOnColdLaunchEvenWhenCompletionWasPersisted() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: iOSUserDefaultsKeys.App.hasCompletedOnboarding)

        let store = iOSOnboardingStore(
            defaults: defaults,
            runtimeFlags: iOSRuntimeFlags(environment: [iOSRuntimeFlags.forceOnboardingEnvironmentKey: "1"])
        )

        #expect(store.shouldShowOnboarding)
        #expect(store.hasCompletedOnboarding)
        #expect(store.isForceOnboardingLaunch)
    }

    @Test func completingOnboardingPersistsStateAndClearsLaunchOverride() {
        let defaults = makeDefaults()
        let store = iOSOnboardingStore(
            defaults: defaults,
            runtimeFlags: iOSRuntimeFlags(environment: [iOSRuntimeFlags.forceOnboardingEnvironmentKey: "1"])
        )

        store.completeOnboarding()

        #expect(store.shouldShowOnboarding == false)
        #expect(store.hasCompletedOnboarding)
        #expect(store.isForceOnboardingLaunch == false)
        #expect(defaults.object(forKey: iOSUserDefaultsKeys.App.hasCompletedOnboarding) as? Bool == true)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "iOSOnboardingStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
