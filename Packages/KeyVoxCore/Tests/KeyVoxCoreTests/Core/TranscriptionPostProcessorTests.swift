import Foundation
import XCTest
@testable import KeyVoxCore

@MainActor
final class TranscriptionPostProcessorTests: XCTestCase {
    func testAppliesDictionaryCasingBeforeListFormatting() async {
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

    func testAppliesInitialAppNameDictionaryEntry() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "My app is called Keybox.",
            dictionaryEntries: [DictionaryInitialEntries.keyVox],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "My app is called KeyVox.")
    }

    func testAppliesInitialBrandNameNearMisses() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Have you heard of Kivox? Keyvox works.",
            dictionaryEntries: [DictionaryInitialEntries.keyVox],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Have you heard of KeyVox? KeyVox works.")
    }

    func testDoesNotApplyInitialBrandNameToFuzzyPluralSplit() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I said key vocals.",
            dictionaryEntries: [DictionaryInitialEntries.keyVox],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I said key vocals.")
    }

    func testAppliesInitialBrandNameFromSplitPossessive() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I use key vox's shortcuts.",
            dictionaryEntries: [DictionaryInitialEntries.keyVox],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I use KeyVox's shortcuts.")
    }

    func testAppliesInitialBrandNameBeforeTitlecaseSentenceBoundary() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Have you ever heard of Kivox? Yeah, it's a really cool dictation app and has a TTS feature inside of it called KeyVox Speak.",
            dictionaryEntries: [DictionaryInitialEntries.keyVox],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "Have you ever heard of KeyVox? Yeah, it's a really cool dictation app and has a TTS feature inside of it called KeyVox Speak."
        )
    }

    func testDoesNotApplySpeakProductNameWithoutDictionaryEntry() async {
        let processor = TranscriptionPostProcessor()

        let kivokOutput = processor.process(
            "I am using Kivok Speak.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )
        let kivoxOutput = processor.process(
            "I am using Kivox Speak.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )
        let keyvoxOutput = processor.process(
            "I am using Keyvox Speak.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(kivokOutput, "I am using Kivok Speak.")
        XCTAssertEqual(kivoxOutput, "I am using Kivox Speak.")
        XCTAssertEqual(keyvoxOutput, "I am using Keyvox Speak.")
    }

    func testDoesNotApplyVibesProductNameWithoutDictionaryEntry() async {
        let processor = TranscriptionPostProcessor()

        let kivoxOutput = processor.process(
            "I am using Kivox Vibes.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )
        let keyvoxOutput = processor.process(
            "I am using Keyvox Vibes.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(kivoxOutput, "I am using Kivox Vibes.")
        XCTAssertEqual(keyvoxOutput, "I am using Keyvox Vibes.")
    }

    func testDictionaryEntryCasingRemainsTheCanonicalReplacement() async {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryInitialEntries.keyVox,
        ]

        let output = processor.process(
            "My app is called key box.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "My app is called KeyVox.")
    }

    func testListFormattingDisabledKeepsProseAndOtherNormalizations() async {
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
    func testListFormattingEnabledStillFormatsWhenExplicitlyTrue() async {
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
    func testSingleLineModeCollapsesWhitespace() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Hello     world",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Hello world.")
    }
    func testMultilineModePreservesSingleParagraphBreak() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\nSecond paragraph.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.")
    }
    func testMultilineModeCollapsesExtraBlankLines() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\n\n\nSecond paragraph.\n\n\nThird paragraph.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.")
    }
    func testMultilineModeTrimsLeadingAndTrailingBlankLines() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "\n\nFirst paragraph.\n\nSecond paragraph.\n\n",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "First paragraph.\n\nSecond paragraph.")
    }
    func testSingleLineModeFlattensParagraphBreaks() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "First paragraph.\n\nSecond paragraph.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "First paragraph. Second paragraph.")
    }
    func testEmptyInputReturnsEmpty() async {
        let processor = TranscriptionPostProcessor()
        let output = processor.process("", dictionaryEntries: [], renderMode: .multiline)
        XCTAssertTrue(output.isEmpty)
    }
    func testDoesNotFormatQuestionWithStepNumberAsListWhenTwoIsTranscribedAsDigit() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Where did you say 2. pause in step 3. where you talked about it?",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "Where did you say 2. pause in step 3. where you talked about it?")
    }

    func testDoesNotFormatShortSpokenVersionDecimalAsList() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm probably going to release version one point two next week.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "I'm probably going to release version one point two next week.")
    }

    func testDoesNotFormatCompoundSpokenQuantityAsList() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Essentially I'm able to pull one month every thirty two hours.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "Essentially I'm able to pull one month every thirty two hours.")
    }

    func testDoesNotFormatMultiTokenSpokenQuantityAsList() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Essentially I'm able to pull one hundred two hours.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "Essentially I'm able to pull one hundred two hours.")
    }

    func testStillFormatsRealListsWhenUsingInOneInTwoPattern() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I want to summarize this in one first item in two second item",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertTrue(output.contains("1. First item"))
        XCTAssertTrue(output.contains("2. Second item"))
    }

    func testDoesNotFormatQuantifiedChoiceSentenceAsList() async {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "It's only one of those two choices and you're not allowed to have it.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "It's only one of those two choices and you're not allowed to have it.")
    }

    func testSplitsShortNominalListItemFromTrailingCommentary() async {
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
