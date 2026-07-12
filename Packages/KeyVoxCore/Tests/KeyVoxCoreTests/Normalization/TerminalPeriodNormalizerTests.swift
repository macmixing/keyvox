import XCTest
@testable import KeyVoxCore

final class TerminalPeriodNormalizerTests: XCTestCase {
    func testAppendsPeriodToOrdinaryProseWithoutTerminalPunctuation() {
        let output = TerminalPeriodNormalizer().appendTerminalPeriodIfNeeded(to: "Please send the notes tomorrow")

        XCTAssertEqual(output, "Please send the notes tomorrow.")
    }

    func testInsertsPeriodBeforeTrailingWhitespace() {
        let output = TerminalPeriodNormalizer().appendTerminalPeriodIfNeeded(to: "Please send the notes tomorrow  ")

        XCTAssertEqual(output, "Please send the notes tomorrow.  ")
    }

    func testPreservesExistingTerminalSentencePunctuation() {
        let normalizer = TerminalPeriodNormalizer()

        XCTAssertEqual(normalizer.appendTerminalPeriodIfNeeded(to: "This is complete."), "This is complete.")
        XCTAssertEqual(normalizer.appendTerminalPeriodIfNeeded(to: "Is this complete?"), "Is this complete?")
        XCTAssertEqual(normalizer.appendTerminalPeriodIfNeeded(to: "This is complete!"), "This is complete!")
    }

    func testDoesNotAppendPeriodToOneWordText() {
        let output = TerminalPeriodNormalizer().appendTerminalPeriodIfNeeded(to: "Reminder")

        XCTAssertEqual(output, "Reminder")
    }

    func testStripsTerminalPeriodFromOneWordText() {
        let normalizer = TerminalPeriodNormalizer()

        XCTAssertEqual(normalizer.appendTerminalPeriodIfNeeded(to: "Reminder."), "Reminder")
        XCTAssertEqual(normalizer.appendTerminalPeriodIfNeeded(to: "Reminder.  "), "Reminder  ")
    }

    func testPreservesQuestionAndExclamationMarksOnOneWordText() {
        let normalizer = TerminalPeriodNormalizer()

        XCTAssertEqual(normalizer.appendTerminalPeriodIfNeeded(to: "Reminder?"), "Reminder?")
        XCTAssertEqual(normalizer.appendTerminalPeriodIfNeeded(to: "Reminder!"), "Reminder!")
    }

    func testDoesNotAppendPeriodToListOrListItem() {
        let normalizer = TerminalPeriodNormalizer()

        XCTAssertEqual(normalizer.appendTerminalPeriodIfNeeded(to: "1. Buy milk"), "1. Buy milk")
        XCTAssertEqual(
            normalizer.appendTerminalPeriodIfNeeded(to: "one buy milk two buy bread"),
            "one buy milk two buy bread"
        )
    }

    func testAppendsPeriodToOrdinaryProseContainingDomainOrURL() {
        let normalizer = TerminalPeriodNormalizer()

        XCTAssertEqual(
            normalizer.appendTerminalPeriodIfNeeded(to: "Please visit dom.tech and share it"),
            "Please visit dom.tech and share it."
        )
        XCTAssertEqual(
            normalizer.appendTerminalPeriodIfNeeded(to: "Open https://keyvox.app and share it"),
            "Open https://keyvox.app and share it."
        )
    }
}
