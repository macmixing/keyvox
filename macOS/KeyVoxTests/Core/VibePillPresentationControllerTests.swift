import AppKit
import XCTest
@testable import KeyVox

@MainActor
final class VibePillPresentationControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        orderOutVisiblePillWindows()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    override func tearDown() {
        OverlayManager.shared.hide()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        orderOutVisiblePillWindows()
        super.tearDown()
    }

    func testCyclePillStartsHiddenUntilPresented() {
        let controller = VibeCyclePillVisibilityController()

        XCTAssertFalse(controller.isVisible)

        controller.present()

        XCTAssertTrue(controller.isVisible)
    }

    func testCyclePillDismissesAfterPresentation() {
        let controller = VibeCyclePillVisibilityController()

        controller.present()
        controller.dismiss()

        XCTAssertFalse(controller.isVisible)
    }

    func testCyclePillFlipSequenceAdvancesOnlyWhenVisibleContentChanges() {
        let controller = VibeCyclePillVisibilityController()

        controller.present(title: "Casual", state: .normal)
        XCTAssertEqual(controller.flipSequence, 0)

        controller.present(title: "Polished", state: .normal)
        XCTAssertEqual(controller.flipSequence, 1)

        controller.present(title: "Polished", state: .normal)
        XCTAssertEqual(controller.flipSequence, 1)

        controller.dismiss()
        controller.present(title: "Chill", state: .normal)
        XCTAssertEqual(controller.flipSequence, 1)
    }

    func testCyclePillPresentationPublishesCoherentFaceAndVisibility() {
        let controller = VibeCyclePillVisibilityController()

        controller.present(title: "Casual", state: .normal)

        XCTAssertEqual(controller.presentation.title, "Casual")
        XCTAssertEqual(controller.presentation.state, .normal)
        XCTAssertTrue(controller.presentation.isVisible)
        XCTAssertEqual(controller.presentation.flipSequence, 0)
    }

    func testAdoptedVisiblePillSeedsCurrentFaceWithoutFlip() {
        let controller = VibeCyclePillVisibilityController()

        controller.adoptVisiblePill(title: "Casual", state: .normal)

        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.title, "Casual")
        XCTAssertEqual(controller.state, .normal)
        XCTAssertEqual(controller.flipSequence, 0)
    }

    func testAdoptedVisiblePillFlipsWhenNextFaceIsPresented() {
        let controller = VibeCyclePillVisibilityController()
        controller.adoptVisiblePill(title: "Casual", state: .normal)

        controller.present(title: "Polished", state: .normal)

        XCTAssertEqual(controller.title, "Polished")
        XCTAssertEqual(controller.flipSequence, 1)
    }

    func testContinueVisibleCycleForcesFlipAfterDismissStarted() {
        let controller = VibeCyclePillVisibilityController()
        controller.present(title: "Casual", state: .normal)
        controller.dismiss()

        controller.continueVisibleCycle(title: "Polished", state: .normal)

        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.title, "Polished")
        XCTAssertEqual(controller.flipSequence, 1)
    }

    func testContinueVisibleCycleDoesNotFlipWhenFaceIsUnchanged() {
        let controller = VibeCyclePillVisibilityController()
        controller.present(title: "Casual", state: .normal)
        controller.dismiss()

        controller.continueVisibleCycle(title: "Casual", state: .normal)

        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.flipSequence, 0)
    }

    func testDismissPreservesCurrentFaceWithoutAdvancingFlip() {
        let controller = VibeCyclePillVisibilityController()
        controller.present(title: "Casual", state: .normal)
        controller.present(title: "Polished", state: .normal)

        controller.dismiss()

        XCTAssertFalse(controller.isVisible)
        XCTAssertEqual(controller.title, "Polished")
        XCTAssertEqual(controller.flipSequence, 1)
    }

    func testCyclePillWindowStaysVisibleUntilExitDelayCompletes() {
        OverlayManager.shared.showVibeCyclePill(
            title: UUID().uuidString,
            duration: 0.05
        )

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        XCTAssertEqual(visibleCyclePillWindowCount, 1)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        XCTAssertEqual(visibleCyclePillWindowCount, 1)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: VibePillPresentationMetrics.panelRemovalDelay))
        XCTAssertEqual(visibleCyclePillWindowCount, 0)
    }

    func testCyclePillInstallsHostingContentOnFirstShow() {
        OverlayManager.shared.showVibeCyclePill(
            title: UUID().uuidString,
            duration: nil
        )

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        let window = visibleCyclePillWindows.first
        XCTAssertNotNil(window?.contentView)
    }

    func testStandalonePillClearsVisibleCycleState() {
        OverlayManager.shared.showVibeCyclePill(
            title: "Casual",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        XCTAssertTrue(OverlayManager.shared.isVibeCyclePillVisible)

        OverlayManager.shared.showVibePill(
            title: "Casual",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        XCTAssertFalse(OverlayManager.shared.isVibeCyclePillVisible)
        XCTAssertEqual(visibleStandalonePillWindowCount, 1)
        XCTAssertEqual(visibleCyclePillWindowCount, 0)
    }

    func testRecordingOverlayClearsVisibleCycleState() {
        OverlayManager.shared.showVibeCyclePill(
            title: "Casual",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        XCTAssertTrue(OverlayManager.shared.isVibeCyclePillVisible)

        OverlayManager.shared.show(recorder: AudioRecorder())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        XCTAssertFalse(OverlayManager.shared.isVibeCyclePillVisible)
        XCTAssertEqual(visibleCyclePillWindowCount, 0)
    }

    func testHideOrdersOutVisibleCyclePillPanel() {
        OverlayManager.shared.showVibeCyclePill(
            title: "Casual",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        XCTAssertEqual(visibleCyclePillWindowCount, 1)

        OverlayManager.shared.hide()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        XCTAssertFalse(OverlayManager.shared.isVibeCyclePillVisible)
        XCTAssertEqual(visibleCyclePillWindowCount, 0)
    }

    func testStandalonePillCanBeAdoptedIntoCyclePill() {
        OverlayManager.shared.showVibePill(
            title: "Casual",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        XCTAssertTrue(OverlayManager.shared.prepareVibePillCycleHandoff())

        OverlayManager.shared.showVibeCyclePill(
            title: "Polished",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.06))

        XCTAssertTrue(OverlayManager.shared.isVibeCyclePillVisible)
        XCTAssertEqual(visibleCyclePillWindowCount, 1)
        XCTAssertEqual(visibleStandalonePillWindowCount, 0)
    }

    func testCycleToStandaloneToCycleAlternationLeavesSingleCyclePanel() {
        OverlayManager.shared.showVibeCyclePill(
            title: "Casual",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        XCTAssertEqual(visibleCyclePillWindowCount, 1)

        OverlayManager.shared.showVibePill(
            title: "Polished",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        XCTAssertEqual(visibleStandalonePillWindowCount, 1)
        XCTAssertEqual(visibleCyclePillWindowCount, 0)

        XCTAssertTrue(OverlayManager.shared.prepareVibePillCycleHandoff())
        OverlayManager.shared.showVibeCyclePill(
            title: "Chill",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.06))

        XCTAssertEqual(visibleCyclePillWindowCount, 1)
        XCTAssertEqual(visibleStandalonePillWindowCount, 0)
        XCTAssertTrue(OverlayManager.shared.isVibeCyclePillVisible)
    }

    func testRepeatedCycleShowsReuseSingleCyclePanel() {
        OverlayManager.shared.showVibeCyclePill(
            title: "Casual",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        OverlayManager.shared.showVibeCyclePill(
            title: "Polished",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        OverlayManager.shared.showVibeCyclePill(
            title: "Chill",
            duration: nil
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

        XCTAssertEqual(visibleCyclePillWindowCount, 1)
        XCTAssertEqual(visibleStandalonePillWindowCount, 0)
    }

    private var visibleCyclePillWindowCount: Int {
        visibleCyclePillWindows.count
    }

    private var visibleCyclePillWindows: [NSWindow] {
        OverlayManager.shared.isVibeCyclePillVisible ? visiblePillWindows : []
    }

    private var visibleStandalonePillWindowCount: Int {
        visibleStandalonePillWindows.count
    }

    private var visibleStandalonePillWindows: [NSWindow] {
        OverlayManager.shared.isVibeCyclePillVisible ? [] : visiblePillWindows
    }

    private var visiblePillWindows: [NSWindow] {
        NSApp.windows.filter { window in
            window.isVisible &&
                window is NSPanel &&
                window.frame.size == OverlayPillMetrics.panelSize
        }
    }

    private func orderOutVisiblePillWindows() {
        visiblePillWindows.forEach { window in
            window.orderOut(nil)
        }
    }
}
