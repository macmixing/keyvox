import Foundation
import XCTest
@testable import KeyVoxCore

final class ListFormattingEngineTests: XCTestCase {
    func testFormatsDetectedList() {
        let engine = ListFormattingEngine()
        let text = "Need to do this one buy groceries two walk dog"

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertTrue(output.contains("1. Buy groceries"))
        XCTAssertTrue(output.contains("2. Walk dog"))
    }

    func testLeavesNonListTextUnchanged() {
        let engine = ListFormattingEngine()
        let text = "This is a normal sentence about version 1.2.3 only."

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertTrue(output == text)
    }

    func testFormatsListWhenNumberingSkipsAhead() {
        let engine = ListFormattingEngine()
        let text = "Need to do this one buy groceries two walk dog four call mom"

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertTrue(output == "Need to do this:\n\n1. Buy groceries\n2. Walk dog\n4. Call mom")
    }

    func testLeavesUncertainNumericRangeInProseUnchanged() {
        let engine = ListFormattingEngine()
        let text = """
        One thing real quickly, and that is just to adjust the size of the individual keys. Maybe like, I don't know two or three points taller. Something like that.
        """

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertEqual(output, text)
    }

    func testSplitsSingleWordLastItemFromCommaThenContinuation() {
        let engine = ListFormattingEngine()
        let text = """
        I need to go to the store today to pick up some things:

        1. Apples
        2. Oranges
        3. Bananas, and then I need to go to Target to buy some clothes
        """

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertEqual(
            output,
            "I need to go to the store today to pick up some things:\n\n1. Apples\n2. Oranges\n3. Bananas\n\nAnd then I need to go to Target to buy some clothes"
        )
    }

    func testSplitsSpokenMarkerLastItemFromCommaThenContinuation() {
        let engine = ListFormattingEngine()
        let text = "I need to go to the store today to pick up some things. One, apples, two, oranges, three, bananas, and then I need to go to Target to buy some clothes."

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertEqual(
            output,
            "I need to go to the store today to pick up some things:\n\n1. Apples\n2. Oranges\n3. Bananas\n\nAnd then I need to go to Target to buy some clothes."
        )
    }
}
