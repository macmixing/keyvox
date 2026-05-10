import AppKit
import SwiftUI
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
        XCTAssertNotNil(window?.contentView as? NSHostingView<VibeCyclePillOverlay>)
    }

    private var visibleCyclePillWindowCount: Int {
        visibleCyclePillWindows.count
    }

    private var visibleCyclePillWindows: [NSWindow] {
        NSApp.windows.filter { window in
            window.isVisible &&
            window.ignoresMouseEvents &&
            window.frame.size == LogoBarView.vibePillPanelSize
        }
    }
}
