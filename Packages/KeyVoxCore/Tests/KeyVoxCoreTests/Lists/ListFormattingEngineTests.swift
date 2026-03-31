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

    func testLeavesTextUnchangedWhenNumberingSkipsAhead() {
        let engine = ListFormattingEngine()
        let text = "Need to do this one buy groceries two walk dog four call mom"

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertEqual(output, text)
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

    func testFormatsSpokenListBeforeTimePhraseTrailingSentence() {
        let engine = ListFormattingEngine()
        let text = "Please help me pick up a couple of things from the party store. One, party hats, two, kazoos, three, gift bags, and bring them to my house by about 5:00 PM tomorrow."

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertEqual(
            output,
            "Please help me pick up a couple of things from the party store:\n\n1. Party hats\n2. Kazoos\n3. Gift bags\n\nAnd bring them to my house by about 5:00 PM tomorrow."
        )
    }

    func testSplitsSingleWordLastItemFromSentenceStyleCommentaryAfterExplicitListMarker() {
        let engine = ListFormattingEngine()
        let text = """
        I'm going out of town next week and I need to buy a few things from Walmart:

        1. Socks
        2. Razor blades
        3. Soda. And remind me to buy an extra bottle of shampoo for my suitcase before I leave on my flight tomorrow at 10:00 AM.
        """

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertEqual(
            output,
            "I'm going out of town next week and I need to buy a few things from Walmart:\n\n1. Socks\n2. Razor blades\n3. Soda\n\nAnd remind me to buy an extra bottle of shampoo for my suitcase before I leave on my flight tomorrow at 10:00 AM."
        )
    }

    func testPreservesTerminalPunctuationOnlyForLongerListItems() {
        let engine = ListFormattingEngine()
        let text = """
        1. Write the full summary.
        2. Walk dog.
        3. Double-check the release notes!
        """

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertEqual(
            output,
            "1. Write the full summary.\n2. Walk dog\n3. Double-check the release notes!"
        )
    }

    func testStripsStructuralCommaFromLongerSpokenListItem() {
        let engine = ListFormattingEngine()
        let text = "Need two things one write the full summary, two walk dog"

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertEqual(output, "Need two things:\n\n1. Write the full summary\n2. Walk dog")
    }
}
