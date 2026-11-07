import XCTest
@testable import KeyVox

@MainActor
final class UpdatePromptPanelQueueTests: XCTestCase {
    func testPromptThatHoldsPanelQueuesOtherPromptsUntilDismissed() {
        var queue = UpdatePromptPanelQueue()
        let holdingPrompt = makePrompt(title: "holding", holdsPanel: true)
        let otherPrompt = makePrompt(title: "other", holdsPanel: false)

        XCTAssertTrue(queue.shouldShow(holdingPrompt, isPanelVisible: false))
        XCTAssertFalse(queue.shouldShow(otherPrompt, isPanelVisible: true))
        XCTAssertEqual(queue.takeQueuedPrompt()?.title, otherPrompt.title)
        XCTAssertNil(queue.takeQueuedPrompt())
    }

    func testPromptThatHoldsPanelCanReplaceItself() {
        var queue = UpdatePromptPanelQueue()

        XCTAssertTrue(queue.shouldShow(makePrompt(title: "first", holdsPanel: true), isPanelVisible: false))
        XCTAssertTrue(queue.shouldShow(makePrompt(title: "second", holdsPanel: true), isPanelVisible: true))
    }

    func testPromptsReplaceEachOtherWhenNoneHoldsPanel() {
        var queue = UpdatePromptPanelQueue()

        XCTAssertTrue(queue.shouldShow(makePrompt(title: "first", holdsPanel: false), isPanelVisible: false))
        XCTAssertTrue(queue.shouldShow(makePrompt(title: "second", holdsPanel: false), isPanelVisible: true))
        XCTAssertNil(queue.takeQueuedPrompt())
    }

    func testHeldPanelNoLongerQueuesOnceHidden() {
        var queue = UpdatePromptPanelQueue()

        XCTAssertTrue(queue.shouldShow(makePrompt(title: "holding", holdsPanel: true), isPanelVisible: false))
        XCTAssertTrue(queue.shouldShow(makePrompt(title: "other", holdsPanel: false), isPanelVisible: false))
    }

    private func makePrompt(title: String, holdsPanel: Bool) -> UpdatePrompt {
        UpdatePrompt(
            title: title,
            message: "",
            version: nil,
            build: nil,
            dismissButtonTitle: "",
            primaryButtonTitle: nil,
            onPrimaryAction: nil,
            onDismiss: {},
            holdsPanelUntilDismissed: holdsPanel
        )
    }
}
