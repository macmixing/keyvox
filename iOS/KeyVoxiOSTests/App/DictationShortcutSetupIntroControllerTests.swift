import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct DictationShortcutSetupIntroControllerTests {
    @Test func completedExistingUserReceivesAutomaticPresentation() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasCompletedOnboarding)
        let onboardingStore = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )
        let controller = DictationShortcutSetupIntroController(
            defaults: defaults,
            presentationDelayNanoseconds: 0
        )
        defer { withExtendedLifetime(onboardingStore) {} }

        controller.schedulePresentationIfEligible(onboardingStore: onboardingStore)
        await settlePresentationTask()

        #expect(controller.isPresented)
        #expect(controller.hasPresentedThisLaunch)
    }

    @Test func firstLaunchOnboardingDoesNotReceiveAutomaticPresentation() async {
        let defaults = makeDefaults()
        let onboardingStore = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )
        let controller = DictationShortcutSetupIntroController(
            defaults: defaults,
            presentationDelayNanoseconds: 0
        )

        controller.schedulePresentationIfEligible(onboardingStore: onboardingStore)
        await Task.yield()

        #expect(controller.isPresented == false)
        #expect(controller.hasPresentedThisLaunch == false)
    }

    @Test func handledIntroductionDoesNotPresentAgain() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasCompletedOnboarding)
        let onboardingStore = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )
        let controller = DictationShortcutSetupIntroController(
            defaults: defaults,
            presentationDelayNanoseconds: 0
        )
        controller.markHandled()

        controller.schedulePresentationIfEligible(onboardingStore: onboardingStore)
        await Task.yield()

        #expect(controller.isPresented == false)
        #expect(controller.wantsPresentationOnEligibleLaunch == false)
    }

    @Test func completingOnboardingDuringCurrentLaunchSuppressesAutomaticPresentation() async {
        let defaults = makeDefaults()
        let onboardingStore = OnboardingStore(
            defaults: defaults,
            runtimeFlags: RuntimeFlags(environment: [:])
        )
        onboardingStore.completeOnboarding()
        let controller = DictationShortcutSetupIntroController(
            defaults: defaults,
            presentationDelayNanoseconds: 0
        )

        controller.schedulePresentationIfEligible(onboardingStore: onboardingStore)
        await Task.yield()

        #expect(controller.isPresented == false)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "DictationShortcutSetupIntroControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func settlePresentationTask() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}
