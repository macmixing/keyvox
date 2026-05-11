import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite
import XCTest
@testable import KeyVox

final class MacTriggerTapClassifierTests: XCTestCase {
    func testFirstQuickTapSchedulesSingleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)

        let event = classifier.registerQuickTap(at: 10)

        XCTAssertEqual(event, .scheduleSingleTap)
    }

    func testSecondQuickTapInsideWindowProducesDoubleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        _ = classifier.registerQuickTap(at: 10)

        let event = classifier.registerQuickTap(at: 10.2)

        XCTAssertEqual(event, .doubleTap)
    }

    func testAwaitingSecondTapOnlyAppliesInsideDoubleTapWindow() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)

        XCTAssertFalse(classifier.isAwaitingSecondTap(at: 10))

        _ = classifier.registerQuickTap(at: 10)

        XCTAssertTrue(classifier.isAwaitingSecondTap(at: 10.2))
        XCTAssertFalse(classifier.isAwaitingSecondTap(at: 10.5))
    }

    func testSecondQuickTapOutsideWindowSchedulesNewSingleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        _ = classifier.registerQuickTap(at: 10)

        let event = classifier.registerQuickTap(at: 10.5)

        XCTAssertEqual(event, .scheduleSingleTap)
    }

    func testTapAfterDoubleTapResetsState() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        _ = classifier.registerQuickTap(at: 10)
        XCTAssertEqual(classifier.registerQuickTap(at: 10.2), .doubleTap)

        let event = classifier.registerQuickTap(at: 10.2)

        XCTAssertEqual(event, .scheduleSingleTap)
    }

    func testResetClearsPendingSingleTapState() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        XCTAssertEqual(classifier.registerQuickTap(at: 10), .scheduleSingleTap)

        classifier.reset()

        XCTAssertFalse(classifier.isAwaitingSecondTap(at: 10.1))
        XCTAssertEqual(classifier.registerQuickTap(at: 10.1), .scheduleSingleTap)
    }
}

@MainActor
final class MacVibesTriggerActionControllerTests: XCTestCase {
    override func tearDown() {
        OverlayManager.shared.hide()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        super.tearDown()
    }

    func testPotentialDoubleTapSuppressesRecordingStartOnlyDuringPendingSingleTapWindow() {
        let (controller, defaults, suiteName) = makeController(isModelReady: { true })
        defer { defaults.removePersistentDomain(forName: suiteName) }

        controller.handleQuickTap(at: 10)
        defer { controller.cancelPendingSingleTap() }

        XCTAssertTrue(controller.shouldSuppressRecordingStartForPotentialDoubleTap(at: 10.1))
        XCTAssertFalse(controller.shouldSuppressRecordingStartForPotentialDoubleTap(at: 10.86))
    }

    func testPotentialDoubleTapDoesNotSuppressRecordingStartWhenVibesAreUnavailable() {
        let (controller, defaults, suiteName) = makeController(isModelReady: { false })
        defer { defaults.removePersistentDomain(forName: suiteName) }

        controller.handleQuickTap(at: 10)

        XCTAssertFalse(controller.shouldSuppressRecordingStartForPotentialDoubleTap(at: 10.1))
    }

    func testVisibleCyclePillDefersRecordingStartOnlyWhenVibesAreUsable() {
        let (readyController, readyDefaults, readySuiteName) = makeController(isModelReady: { true })
        defer { readyDefaults.removePersistentDomain(forName: readySuiteName) }
        let (missingController, missingDefaults, missingSuiteName) = makeController(isModelReady: { false })
        defer { missingDefaults.removePersistentDomain(forName: missingSuiteName) }

        XCTAssertTrue(readyController.shouldDeferRecordingStartForVisibleCyclePill(isCyclePillVisible: true))
        XCTAssertFalse(readyController.shouldDeferRecordingStartForVisibleCyclePill(isCyclePillVisible: false))
        XCTAssertFalse(missingController.shouldDeferRecordingStartForVisibleCyclePill(isCyclePillVisible: true))
    }

    func testVisibleStandalonePillHandoffDefersRecordingStartOnlyWhenVibesAreUsable() {
        let (readyController, readyDefaults, readySuiteName) = makeController(isModelReady: { true })
        defer { readyDefaults.removePersistentDomain(forName: readySuiteName) }
        let (missingController, missingDefaults, missingSuiteName) = makeController(isModelReady: { false })
        defer { missingDefaults.removePersistentDomain(forName: missingSuiteName) }

        XCTAssertTrue(readyController.shouldDeferRecordingStartForVibePillCycleHandoff(isVibePillVisible: true))
        XCTAssertFalse(readyController.shouldDeferRecordingStartForVibePillCycleHandoff(isVibePillVisible: false))
        XCTAssertFalse(missingController.shouldDeferRecordingStartForVibePillCycleHandoff(isVibePillVisible: true))
    }

    private func makeController(
        isModelReady: @escaping () -> Bool
    ) -> (MacVibesTriggerActionController, UserDefaults, String) {
        let suiteName = "MacVibesTriggerActionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettingsStore(defaults: defaults)
        settings.selectedVibe = .casual
        let coordinator = MacVibesCoordinator(
            appSettings: settings,
            textTransformer: FakeTriggerActionTextTransformer(),
            isModelReady: isModelReady
        )
        let changeController = MacDictationChangeController(vibesCoordinator: coordinator)
        return (
            MacVibesTriggerActionController(
                appSettings: settings,
                vibesCoordinator: coordinator,
                dictationChangeController: changeController,
                quickTapMaximumDuration: 0.5
            ),
            defaults,
            suiteName
        )
    }
}

@MainActor
private final class FakeTriggerActionTextTransformer: DictationTextTransforming {
    func prewarm(request: TextTransformRequest) {}

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        TextTransformResult(
            originalText: request.baseText,
            finalText: request.baseText,
            styleIdentifier: request.styleIdentifier,
            duration: 0,
            chunkCount: request.baseText.isEmpty ? 0 : 1,
            applied: false,
            chunkTimings: [],
            errors: [],
            processingMode: "fake"
        )
    }
}
