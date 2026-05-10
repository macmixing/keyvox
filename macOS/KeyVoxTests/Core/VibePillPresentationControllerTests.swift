import AppKit
import XCTest
@testable import KeyVox

@MainActor
final class VibePillPresentationControllerTests: XCTestCase {
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

    private var visibleCyclePillWindowCount: Int {
        NSApp.windows.filter { window in
            window.isVisible &&
            window.ignoresMouseEvents &&
            window.frame.size == LogoBarView.vibePillPanelSize
        }.count
    }
}
