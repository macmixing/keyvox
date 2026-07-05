import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class ChillHeuristicFormatterTests: XCTestCase {
    func testChillHeuristicFormatsSentenceSeparatorsWithoutEndingPeriod() {
        let output = ChillHeuristicFormatter().format(
            "Hey, this is really crazy. What are you doing tomorrow? I don't even know what I'm doing tonight, but I think this is cool."
        )

        XCTAssertEqual(
            output,
            "hey this is really crazy. what are you doing tomorrow? i dont even know what im doing tonight but i think this is cool"
        )
    }

    func testChillHeuristicKeepsFinalQuestionMark() {
        let output = ChillHeuristicFormatter().format("Hey what's up man?")

        XCTAssertEqual(output, "hey whats up man?")
    }

    func testChillHeuristicDoesNotOwnFillerRemoval() {
        let output = ChillHeuristicFormatter().format("Um hey uh this is cool.")

        XCTAssertEqual(output, "um hey uh this is cool")
    }

    func testChillHeuristicPreservesEmoji() {
        let output = ChillHeuristicFormatter().format(
            "KeyVox runs on-device and skips the subscription nonsense. 🎙️🔒"
        )

        XCTAssertEqual(
            output,
            "keyvox runs on device and skips the subscription nonsense. 🎙️🔒"
        )
    }

    func testChillHeuristicPreservesMathSymbols() {
        let output = ChillHeuristicFormatter().format("2+2=4")

        XCTAssertEqual(output, "2+2=4")
    }

    func testChillHeuristicPreservesNumericHyphens() {
        let output = ChillHeuristicFormatter().format("Call 602-555-0134 on 2026-05-12.")

        XCTAssertEqual(output, "call 602-555-0134 on 2026-05-12")
    }

    func testChillHeuristicPreservesPostProcessedMathSymbols() {
        let output = ChillHeuristicFormatter().format("Keep (2 - 2 = 0), 3^2 = 9, 8 / 2, 5 * 4, and 50%.")

        XCTAssertEqual(output, "keep (2 - 2 = 0) 3^2 = 9 8 / 2 5 * 4 and 50%")
    }

    func testChillHeuristicCollapsesColonBetweenNumbers() {
        let output = ChillHeuristicFormatter().format("Meet at 5:45 and keep the ratio 16:9, but remove this: colon.")

        XCTAssertEqual(output, "meet at 545 and keep the ratio 169 but remove this colon")
    }

    func testChillHeuristicPreservesEmailAddress() {
        let output = ChillHeuristicFormatter().format("dom@example.com")

        XCTAssertEqual(output, "dom@example.com")
    }

    func testChillHeuristicPreservesEmailAddressWithTrailingSentencePunctuation() {
        let output = ChillHeuristicFormatter().format("Email dom@example.com. Then wait.")

        XCTAssertEqual(output, "email dom@example.com. then wait")
    }

    func testChillHeuristicPreservesParagraphBreaks() {
        let output = ChillHeuristicFormatter().format(
            "Hey, this is really crazy.\n\nWhat are you doing tomorrow? I don't even know."
        )

        XCTAssertEqual(
            output,
            "hey this is really crazy\n\nwhat are you doing tomorrow? i dont even know"
        )
    }

    func testChillHeuristicPreservesOrderedListLineBreaks() {
        let output = ChillHeuristicFormatter().format(
            "I need to pick up a couple of things from the store.\n\n1. Apples\n2. Bananas"
        )

        XCTAssertEqual(
            output,
            "i need to pick up a couple of things from the store\n\n1. apples\n2. bananas"
        )
    }
}
