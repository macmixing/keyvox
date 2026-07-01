import XCTest
@testable import KeyVoxCore

final class TerminalPunctuationNormalizerTests: XCTestCase {
    func testConvertsTerminalQuestionMarkCommand() {
        let normalizer = TerminalPunctuationNormalizer()

        let output = normalizer.normalizeSpokenTerminalPunctuation(in: "Is this ready question mark")

        XCTAssertEqual(output, "Is this ready?")
    }

    func testConvertsTerminalExclamationCommands() {
        let normalizer = TerminalPunctuationNormalizer()

        let pointOutput = normalizer.normalizeSpokenTerminalPunctuation(in: "Ship it exclamation point")
        let markOutput = normalizer.normalizeSpokenTerminalPunctuation(in: "Ship it exclamation mark")
        let imperativeOutput = normalizer.normalizeSpokenTerminalPunctuation(in: "Run exclamation point.")

        XCTAssertEqual(pointOutput, "Ship it!")
        XCTAssertEqual(markOutput, "Ship it!")
        XCTAssertEqual(imperativeOutput, "Run!")
    }

    func testConvertsRepeatedTerminalCommandsInOrder() {
        let normalizer = TerminalPunctuationNormalizer()

        let questionOutput = normalizer.normalizeSpokenTerminalPunctuation(in: "question mark question mark")
        let pointOutput = normalizer.normalizeSpokenTerminalPunctuation(
            in: "exclamation point exclamation point"
        )
        let mixedMarkOutput = normalizer.normalizeSpokenTerminalPunctuation(
            in: "exclamation mark exclamation point"
        )
        let questionPointOutput = normalizer.normalizeSpokenTerminalPunctuation(
            in: "question mark exclamation point"
        )
        let pointQuestionOutput = normalizer.normalizeSpokenTerminalPunctuation(
            in: "exclamation point question mark"
        )

        XCTAssertEqual(questionOutput, "??")
        XCTAssertEqual(pointOutput, "!!")
        XCTAssertEqual(mixedMarkOutput, "!!")
        XCTAssertEqual(questionPointOutput, "?!")
        XCTAssertEqual(pointQuestionOutput, "!?")
    }

    func testConvertsRepeatedTerminalCommandAfterConjunctionWithoutRemovingConjunction() {
        let normalizer = TerminalPunctuationNormalizer()

        let output = normalizer.normalizeSpokenTerminalPunctuation(
            in: "Are you crazy or question mark exclamation point?"
        )

        XCTAssertEqual(output, "Are you crazy or?!")
    }

    func testIgnoresSurroundingPunctuationForTerminalCommands() {
        let normalizer = TerminalPunctuationNormalizer()

        XCTAssertEqual(normalizer.normalizeSpokenTerminalPunctuation(in: "Ready, question mark."), "Ready?")
        XCTAssertEqual(normalizer.normalizeSpokenTerminalPunctuation(in: "question mark."), "?")
        XCTAssertEqual(normalizer.normalizeSpokenTerminalPunctuation(in: "(question mark)"), "?")
        XCTAssertEqual(normalizer.normalizeSpokenTerminalPunctuation(in: "question mark!"), "?")
    }

    func testConvertsTerminalCommandBeforeFollowingSentence() {
        let normalizer = TerminalPunctuationNormalizer()

        let output = normalizer.normalizeSpokenTerminalPunctuation(
            in: "That's crazy exclamation point. Your wild question mark"
        )

        XCTAssertEqual(output, "That's crazy! Your wild?")
    }

    func testConvertsTerminalCommandAfterCommaBoundary() {
        let normalizer = TerminalPunctuationNormalizer()

        let output = normalizer.normalizeSpokenTerminalPunctuation(
            in: "What is your problem, exclamation point?"
        )

        XCTAssertEqual(output, "What is your problem!")
    }

    func testConvertsTerminalCommandAfterNounPhraseWithoutCommaBoundary() {
        let normalizer = TerminalPunctuationNormalizer()

        let output = normalizer.normalizeSpokenTerminalPunctuation(
            in: "Here's the update exclamation point."
        )

        XCTAssertEqual(output, "Here's the update!")
    }

    func testConvertsTerminalCommandAfterShortVerbPhrase() {
        let normalizer = TerminalPunctuationNormalizer()

        let output = normalizer.normalizeSpokenTerminalPunctuation(
            in: "We won exclamation point."
        )

        XCTAssertEqual(output, "We won!")
    }

    func testConvertsTerminalQuestionCommandAfterDeterminerPhrase() {
        let normalizer = TerminalPunctuationNormalizer()

        let output = normalizer.normalizeSpokenTerminalPunctuation(
            in: "That's cool. So you're a big fan of that question mark."
        )

        XCTAssertEqual(output, "That's cool. So you're a big fan of that?")
    }

    func testDoesNotConvertProtectedDeterminerCommandEdges() {
        let normalizer = TerminalPunctuationNormalizer()

        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "That question mark."),
            "That question mark."
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "I'm a fan of that question mark"),
            "I'm a fan of that question mark"
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "Of that question mark."),
            "Of that question mark."
        )
    }

    func testDoesNotConvertOrdinaryReferences() {
        let normalizer = TerminalPunctuationNormalizer()

        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "The phrase question mark"),
            "The phrase question mark"
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "I said exclamation point"),
            "I said exclamation point"
        )
        // A leading capitalized verb can still be a punctuation-word reference.
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "Said exclamation point"),
            "Said exclamation point"
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "I noted question mark"),
            "I noted question mark"
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "I typed exclamation point"),
            "I typed exclamation point"
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "I typed that question mark."),
            "I typed that question mark."
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "I declared exclamation mark"),
            "I declared exclamation mark"
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "I asked question mark"),
            "I asked question mark"
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(in: "The symbol exclamation mark"),
            "The symbol exclamation mark"
        )
        XCTAssertEqual(
            normalizer.normalizeSpokenTerminalPunctuation(
                in: "If someone decides to add their own question mark or exclamation point, I don't care, but that's fine."
            ),
            "If someone decides to add their own question mark or exclamation point, I don't care, but that's fine."
        )
    }

    func testDoesNotConvertUnsupportedTerminalPunctuationWords() {
        let normalizer = TerminalPunctuationNormalizer()

        XCTAssertEqual(normalizer.normalizeSpokenTerminalPunctuation(in: "Finish this period"), "Finish this period")
        XCTAssertEqual(normalizer.normalizeSpokenTerminalPunctuation(in: "Keep going comma"), "Keep going comma")
    }
}
