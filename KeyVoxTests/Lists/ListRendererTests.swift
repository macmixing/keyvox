import Foundation
import XCTest
@testable import KeyVox

final class ListRendererTests: XCTestCase {
    func testRendersMultilineWithLeadInColonAndTrailingText() {
        let renderer = ListRenderer()
        let list = DetectedList(
            leadingText: "Here is the plan",
            items: [
                DetectedListItem(spokenIndex: 1, content: "Get dog food"),
                DetectedListItem(spokenIndex: 2, content: "Charge phone"),
            ],
            trailingText: "Then we rest"
        )

        let rendered = renderer.render(list, mode: .multiline)
        XCTAssertTrue(rendered == "Here is the plan:\n\n1. Get dog food\n2. Charge phone\n\nThen we rest")
    }

    func testRendersSingleLineInlineWithSemicolons() {
        let renderer = ListRenderer()
        let list = DetectedList(
            leadingText: "Tasks",
            items: [
                DetectedListItem(spokenIndex: 1, content: "Call vet"),
                DetectedListItem(spokenIndex: 2, content: "Buy food"),
            ],
            trailingText: "done"
        )

        let rendered = renderer.render(list, mode: .singleLineInline)
        XCTAssertTrue(rendered == "Tasks: 1. Call vet; 2. Buy food done")
    }

    func testCapitalizesFirstLetterOfTrailingTransition() {
        let renderer = ListRenderer()
        let list = DetectedList(
            leadingText: "Here is the plan",
            items: [
                DetectedListItem(spokenIndex: 1, content: "Get dog food"),
                DetectedListItem(spokenIndex: 2, content: "Charge phone"),
            ],
            trailingText: "and everything is handled"
        )

        let rendered = renderer.render(list, mode: .multiline)
        XCTAssertTrue(rendered == "Here is the plan:\n\n1. Get dog food\n2. Charge phone\n\nAnd everything is handled")
    }
}
