import Foundation
import XCTest
@testable import KeyVoxCore

@MainActor
final class TranscriptionPostProcessorTests: XCTestCase {
    func testAppliesDictionaryCasingBeforeListFormatting() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "Cueboard"),
        ]

        let output = processor.process(
            "Okay one cueboard two cueboard",
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertTrue(output.contains("1. Cueboard"))
        XCTAssertTrue(output.contains("2. Cueboard"))
    }

    func testListFormattingDisabledKeepsProseAndOtherNormalizations() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "Cueboard")]

        let output = processor.process(
            "Need to do this one cue board two cue board ha ha 415 pm",
            dictionaryEntries: entries,
            renderMode: .multiline,
            listFormattingEnabled: false
        )

        XCTAssertEqual(output, "Need to do this one Cueboard two Cueboard haha 4:15 PM.")
    }
    func testListFormattingEnabledStillFormatsWhenExplicitlyTrue() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "Cueboard")]

        let output = processor.process(
            "Need to do this one cue board two cue board",
            dictionaryEntries: entries,
            renderMode: .multiline,
            listFormattingEnabled: true
        )

        XCTAssertTrue(output.contains("1. Cueboard"))
        XCTAssertTrue(output.contains("2. Cueboard"))
    }
    func testSingleLineModeCollapsesWhitespace() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Hello     world",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Hello world")
    }
    func testMultilineModePreservesSingleParagraphBreak() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\nSecond paragraph.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.")
    }
    func testMultilineModeCollapsesExtraBlankLines() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\n\n\nSecond paragraph.\n\n\nThird paragraph.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.")
    }
    func testMultilineModeTrimsLeadingAndTrailingBlankLines() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "\n\nFirst paragraph.\n\nSecond paragraph.\n\n",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.")
    }
    func testSingleLineModeFlattensParagraphBreaks() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\nSecond paragraph.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "First paragraph. Second paragraph.")
    }
    func testEmptyInputReturnsEmpty() {
        let processor = TranscriptionPostProcessor()
        let output = processor.process("", dictionaryEntries: [], renderMode: .multiline)
        XCTAssertTrue(output.isEmpty)
    }
    func testDoesNotFormatQuestionWithStepNumberAsListWhenTwoIsTranscribedAsDigit() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Where did you say 2. pause in step 3. where you talked about it?",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "Where did you say 2. pause in step 3. where you talked about it?")
    }
    func testStillFormatsRealListsWhenUsingInOneInTwoPattern() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I want to summarize this in one first item in two second item",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertTrue(output.contains("1. First item"))
        XCTAssertTrue(output.contains("2. Second item"))
    }

    func testDoesNotFormatQuantifiedChoiceSentenceAsList() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "It's only one of those two choices and you're not allowed to have it.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "It's only one of those two choices and you're not allowed to have it.")
    }

    func testSplitsShortNominalListItemFromTrailingCommentary() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "It's either going to be one a dresser two a chair, and honestly I don't think you're going to pick wrong",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            "It's either going to be:\n\n1. A dresser\n2. A chair\n\nAnd honestly I don't think you're going to pick wrong"
        )
    }
}
