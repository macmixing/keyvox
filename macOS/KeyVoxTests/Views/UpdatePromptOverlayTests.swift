import AppKit
import SwiftUI
import XCTest
@testable import KeyVox

@MainActor
final class UpdatePromptOverlayTests: XCTestCase {
    func testShortMessagePromptStaysBelowMaximumHeight() {
        let height = fittingHeight(message: messageLines(1))

        XCTAssertGreaterThan(height, 0)
        XCTAssertLessThan(height, UpdatePromptLayout.maxHeight)
    }

    func testPromptGrowsWithMessageBelowMaximumHeight() {
        let shortHeight = fittingHeight(message: messageLines(1))
        let longerHeight = fittingHeight(message: messageLines(6))

        XCTAssertGreaterThan(longerHeight, shortHeight)
        XCTAssertLessThan(longerHeight, UpdatePromptLayout.maxHeight)
    }

    func testLongMessagePromptStopsAtMaximumHeight() {
        let height = fittingHeight(message: messageLines(80))

        XCTAssertEqual(height, UpdatePromptLayout.maxHeight, accuracy: 0.5)
    }

    private func fittingHeight(message: String) -> CGFloat {
        let prompt = UpdatePrompt(
            title: "Title",
            message: message,
            version: nil,
            build: nil,
            dismissButtonTitle: "Later",
            primaryButtonTitle: "Download",
            onPrimaryAction: nil,
            onDismiss: {}
        )
        let hostingView = NSHostingView(
            rootView: UpdatePromptOverlay(prompt: prompt, onPrimaryAction: {}, onDismiss: {})
        )
        return hostingView.fittingSize.height
    }

    private func messageLines(_ count: Int) -> String {
        (1...count).map { "Summary line \($0) describing a change in this release." }.joined(separator: "\n")
    }
}
