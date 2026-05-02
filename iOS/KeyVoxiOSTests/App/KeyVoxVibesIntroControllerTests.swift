import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyVoxVibesIntroControllerTests {
    @Test func schedulesOnEligibleLaunchWhenUnseenAndUnused() async throws {
        let harness = makeHarness(hasCompletedOnboarding: true)
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        controller.schedulePresentationIfEligible()
        await settlePresentationTask()

        #expect(controller.isPresented == true)
    }

    @Test func doesNotShowOverOnboarding() async throws {
        let harness = makeHarness(hasCompletedOnboarding: false)
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        controller.handleAppDidBecomeActive(
            onboardingStore: harness.onboardingStore,
            isShowingReturnToHost: false
        )
        await settlePresentationTask()

        #expect(controller.isPresented == false)
    }

    @Test func doesNotShowOverReturnToHost() async throws {
        let harness = makeHarness(hasCompletedOnboarding: true)
        defer { harness.cleanup() }
        harness.defaults.set(true, forKey: UserDefaultsKeys.App.shouldShowKeyVoxVibesIntroOnNextEligibleLaunch)

        let controller = makeController(harness: harness)
        controller.handleAppDidBecomeActive(
            onboardingStore: harness.onboardingStore,
            isShowingReturnToHost: true
        )
        await settlePresentationTask()

        #expect(controller.isPresented == false)
    }

    @Test func sceneBOnlyPresentationPathIsAvailable() async throws {
        let harness = makeHarness(hasCompletedOnboarding: true)
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        controller.present(introPresentation: .usageOnly)

        #expect(controller.isPresented == true)
        #expect(controller.introPresentation == .usageOnly)
    }

    private func makeHarness(hasCompletedOnboarding: Bool) -> KeyVoxVibesIntroHarness {
        let suiteName = "KeyVoxVibesIntroControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(hasCompletedOnboarding, forKey: UserDefaultsKeys.App.hasCompletedOnboarding)
        defaults.set(hasCompletedOnboarding, forKey: UserDefaultsKeys.App.hasCompletedOnboardingWelcome)
        return KeyVoxVibesIntroHarness(
            defaults: defaults,
            onboardingStore: OnboardingStore(defaults: defaults, runtimeFlags: RuntimeFlags(environment: [:])),
            suiteName: suiteName
        )
    }

    private func makeController(harness: KeyVoxVibesIntroHarness) -> KeyVoxVibesIntroController {
        KeyVoxVibesIntroController(
            defaults: harness.defaults,
            presentationDelayNanoseconds: 0
        )
    }

    private func settlePresentationTask() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}

@MainActor
private final class KeyVoxVibesIntroHarness {
    let defaults: UserDefaults
    let onboardingStore: OnboardingStore
    private let suiteName: String

    init(defaults: UserDefaults, onboardingStore: OnboardingStore, suiteName: String) {
        self.defaults = defaults
        self.onboardingStore = onboardingStore
        self.suiteName = suiteName
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
