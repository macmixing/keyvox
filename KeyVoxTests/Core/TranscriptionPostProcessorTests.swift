import Foundation
import XCTest
@testable import KeyVox

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

    func testNormalizesCompactAndDottedTimesWithMeridiem() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "315 a.m. 317AM 4.19pm",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "3:15 AM 3:17 AM 4:19 PM")
    }

    func testPreservesDaypartPhrasingWhileFixingTimeShape() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I got there at 418 in the morning and left at 4.19 in the evening",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I got there at 4:18 in the morning and left at 4:19 in the evening")
    }

    func testPreservesDaypartPhrasingForHyphenSeparatedTimes() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think maybe 3-15 in the evening?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I think maybe 3:15 in the evening?")
    }

    func testNormalizesTerminalAndAsFuzzyAm() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "415-AND. 315 and",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "4:15 AM. 3:15 AM")
    }

    func testDoesNotTreatConjunctionAndAsMeridiem() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I said 415 and 530 in the afternoon",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I said 415 and 5:30 in the afternoon")
    }

    func testNormalizesHaHaToHaha() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Ha ha that was funny",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "haha that was funny")
    }

    func testKeepsBetweenColonPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Let's pick between colon McDonalds or Burger King",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Let's pick between colon McDonalds or Burger King")
    }

    func testKeepsBetweenColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Let's pick between Colin McDonalds or Burger King",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Let's pick between Colin McDonalds or Burger King")
    }

    func testKeepsCommaDelimitedColonPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm going to the store, colon, to buy some groceries.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I'm going to the store, colon, to buy some groceries.")
    }

    func testKeepsCommaDelimitedColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm going to the store, Colin, to buy some groceries.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I'm going to the store, Colin, to buy some groceries.")
    }

    func testKeepsStandaloneColonWordWithoutContext() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The word colon appears here",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "The word colon appears here")
    }

    func testKeepsTerminalCommaDelimitedColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Next task, Colin.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Next task, Colin.")
    }

    func testDoesNotRewriteSingleWordGreetingColin() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Hi, Colin.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Hi, Colin.")
    }
}
