import XCTest
@testable import KeyVox

@MainActor
final class MacVibesIntroControllerTests: XCTestCase {
    func testSchedulesIntroWhenOnboardingIsCompleteAndIntroHasNotBeenSeen() {
        let harness = makeHarness()
        let controller = MacVibesIntroController(
            defaults: harness.defaults,
            presentationDelayNanoseconds: 0
        )
        var presentationCount = 0

        controller.scheduleColdLaunchPresentationIfNeeded(hasCompletedOnboarding: true) {
            presentationCount += 1
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        XCTAssertEqual(presentationCount, 1)
        XCTAssertTrue(harness.defaults.bool(forKey: UserDefaultsKeys.App.hasSeenKeyVoxVibesIntro))
        harness.cleanup()
    }

    func testDoesNotScheduleIntroBeforeMainOnboardingCompletes() {
        let harness = makeHarness()
        let controller = MacVibesIntroController(
            defaults: harness.defaults,
            presentationDelayNanoseconds: 0
        )
        var didPresent = false

        controller.scheduleColdLaunchPresentationIfNeeded(hasCompletedOnboarding: false) {
            didPresent = true
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        XCTAssertFalse(didPresent)
        XCTAssertFalse(harness.defaults.bool(forKey: UserDefaultsKeys.App.hasSeenKeyVoxVibesIntro))
        harness.cleanup()
    }

    func testForceIntroEnvironmentPresentsWithoutClearingSeenDefault() {
        let harness = makeHarness()
        harness.defaults.set(true, forKey: UserDefaultsKeys.App.hasSeenKeyVoxVibesIntro)
        let controller = MacVibesIntroController(
            defaults: harness.defaults,
            environment: [MacVibesIntroController.forceIntroEnvironmentKey: "1"],
            presentationDelayNanoseconds: 0
        )
        var presentationCount = 0

        controller.scheduleColdLaunchPresentationIfNeeded(hasCompletedOnboarding: true) {
            presentationCount += 1
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        XCTAssertEqual(presentationCount, 1)
        XCTAssertTrue(controller.shouldForcePresentation)
        harness.cleanup()
    }

    private func makeHarness() -> Harness {
        let suiteName = "MacVibesIntroControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return Harness(defaults: defaults, suiteName: suiteName)
    }

    private struct Harness {
        let defaults: UserDefaults
        let suiteName: String

        func cleanup() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}
