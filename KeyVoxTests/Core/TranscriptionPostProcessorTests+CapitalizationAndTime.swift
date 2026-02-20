import Foundation
import XCTest
@testable import KeyVox

@MainActor
extension TranscriptionPostProcessorTests {
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
    func testAddsPeriodWhenSentenceEndsWithFormattedTime() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Go ahead and send me an email next week at 2:35 PM",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Go ahead and send me an email next week at 2:35 PM.")
    }
    func testCapitalizesLowercaseWordAfterSentenceBoundaryPunctuation() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Can you send me the notes? and then follow up tomorrow! then cc the team.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Can you send me the notes? And then follow up tomorrow! Then cc the team.")
    }
    func testCapitalizesAndAfterPeriodInUserPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think you're so cool. and honestly, I wish I could be like you.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I think you're so cool. And honestly, I wish I could be like you.")
    }
    func testCapitalizesAndAfterPeriodInFollowUpUserPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think you're so cool. and honestly, we should hang out.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I think you're so cool. And honestly, we should hang out.")
    }
    func testCapitalizesLeadingAndAtChunkStart() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "and honestly, we should hang out.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "And honestly, we should hang out.")
    }
    func testCapitalizesAndAfterPeriodWhenRestartHasNoSpace() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think you're so cool.and honestly, I wish I could be like you.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I think you're so cool. And honestly, I wish I could be like you.")
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

    func testForceAllCapsAppliesAfterNormalizationPipeline() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "Cueboard"),
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "www.keyvox.app")
        ]
        let input = """
        project notes one cue board two cue board at 415 pm

        visit www.KeyVox.app and email dom@example.com
        """

        let output = processor.process(
            input,
            dictionaryEntries: entries,
            renderMode: .multiline,
            listFormattingEnabled: true,
            forceAllCaps: true
        )

        XCTAssertTrue(output.contains("PROJECT NOTES:"))
        XCTAssertTrue(output.contains("\n1. CUEBOARD"))
        XCTAssertTrue(output.contains("\n2. CUEBOARD AT 4:15 PM"))
        XCTAssertTrue(output.contains("VISIT WWW.KEYVOX.APP AND EMAIL DOM@EXAMPLE.COM"))
        XCTAssertFalse(output.contains("Cueboard"))
        XCTAssertEqual(output, output.uppercased())
    }

    func testForceAllCapsKeepsExistingNumericListShapeAndUppercasesContent() {
        let processor = TranscriptionPostProcessor()
        let input = "1. dom@example.com\n2. www.example.com"

        let output = processor.process(
            input,
            dictionaryEntries: [DictionaryEntry(phrase: "Dom")],
            renderMode: .multiline,
            listFormattingEnabled: true,
            forceAllCaps: true
        )

        XCTAssertEqual(output, input.uppercased())
    }

    func testForceAllCapsFormatsUppercaseSpokenNumberMarkers() {
        let processor = TranscriptionPostProcessor()
        let input = "THINGS TO DO ONE EMAIL DOM AT EXAMPLE.COM TWO VISIT WWW.EXAMPLE.COM"

        let output = processor.process(
            input,
            dictionaryEntries: [DictionaryEntry(phrase: "dom@example.com")],
            renderMode: .multiline,
            listFormattingEnabled: true,
            forceAllCaps: true
        )

        XCTAssertTrue(output.contains("THINGS TO DO:"))
        XCTAssertTrue(output.contains("\n1. EMAIL DOM@EXAMPLE.COM"))
        XCTAssertTrue(output.contains("\n2. VISIT WWW.EXAMPLE.COM"))
        XCTAssertEqual(output, output.uppercased())
    }
}
