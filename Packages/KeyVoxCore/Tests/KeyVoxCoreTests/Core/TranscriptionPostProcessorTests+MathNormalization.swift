import Foundation
import XCTest
@testable import KeyVoxCore

@MainActor
extension TranscriptionPostProcessorTests {
    func testNormalizesBasicSpokenAddition() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "12 plus 8",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "12 + 8")
    }

    func testNormalizesFullySpelledOutAdditionEquation() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Two plus two equals four.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "2 + 2 = 4")
    }

    func testNormalizesSpelledOutEqualsOperandAfterBinaryNormalization() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "2 + 2 equals four.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "2 + 2 = 4")
    }

    func testNormalizesFullySpelledOutMultiwordMathEquation() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Forty two minus seven equals thirty five.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "42 - 7 = 35")
    }

    func testNormalizesPercentEqualsAndExponentPhrases() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "3 squared equals 9 and 50 percent",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "3^2 = 9 and 50%")
    }

    func testNormalizesCubedToExponent() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "4 cubed",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "4^3")
    }

    func testNormalizesToThePowerOfPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "2 to the power of 5",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "2^5")
    }

    func testNormalizesToTheOrdinalPowerPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "7 to the fourth power",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "7^4")
    }

    func testNormalizesRaisedToPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "9 raised to 3",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "9^3")
    }

    func testNormalizesRaisedToOrdinalPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "9 raised to the third power",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "9^3")
    }

    func testNormalizesCompoundOrdinalPowerPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "2 to the twenty first power",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "2^21")
    }

    func testNormalizesXMultiplicationThenPlusForStandaloneMath() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "2x2, plus 6.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "2 * 2 + 6")
    }

    func testNormalizesXMultiplicationThenDivisionForStandaloneMath() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "4x5 divided by 2.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "4 * 5 / 2")
    }

    func testNormalizesCombinedOperatorPhrasesInSingleUtterance() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "2x2 plus 6 divided by 3.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "2 * 2 + 6 / 3")
    }

    func testPreservesCompactHyphenatedNumericSequences() {
        let processor = TranscriptionPostProcessor()

        XCTAssertEqual(
            processor.process(
                "2-15-62",
                dictionaryEntries: [],
                renderMode: .singleLineInline
            ),
            "2-15-62"
        )

        XCTAssertEqual(
            processor.process(
                "7-15-03",
                dictionaryEntries: [],
                renderMode: .singleLineInline
            ),
            "7-15-03"
        )

        XCTAssertEqual(
            processor.process(
                "12-20-89",
                dictionaryEntries: [],
                renderMode: .singleLineInline
            ),
            "12-20-89"
        )
    }

    func testPreservesTerminalPunctuationForSentenceContainingCombinedMathPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Please compute 2x2, plus 6.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Please compute 2 * 2 + 6.")
    }

    func testNormalizesSubtractWordingInStandaloneMath() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "10 subtract 3.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "10 - 3")
    }

    func testNormalizesSubtractedByWordingInStandaloneMath() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "10 subtracted by 3.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "10 - 3")
    }

    func testNormalizesSymbolicDivisionFollowedByMultipliedByPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "50 / 2 multiplied by 6.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "50 / 2 * 6")
    }

    func testNormalizesMathInsideParagraphsWithoutChangingStructure() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            """
            Budget update:
            we calculated 12 plus 8 for phase one.

            then 3 power of 2 equals 9.
            """,
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            Budget update:
            We calculated 12 + 8 for phase one.

            Then 3^2 = 9.
            """
        )
    }

    func testNormalizesMathInsideNumberedListsWithoutBreakingMarkers() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            """
            1. 12 plus 8
            2. 50 percent
            3. 3 squared
            """,
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            1. 12 + 8
            2. 50%
            3. 3^2
            """
        )
    }

    func testSkipsUrlAndEmailTokensWhileStillNormalizingMathInSentence() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "dom@example.com")]

        let output = processor.process(
            "Visit www.example.com and email dom@example.com then compute 12 plus 8.",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Visit www.example.com and email dom@example.com then compute 12 + 8.")
    }


    func testSkipsTimeDateAndVersionShapes() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Meet at 4:15 PM on 2026-02-19 and version 1.2.3 while we do 12 plus 8.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Meet at 4:15 PM on 2026-02-19 and version 1.2.3 while we do 12 + 8.")
    }

    func testTreatsHyphenAsSubtractionOnlyBetweenNumbers() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Date 2026-02-19 but 12-8 is subtraction.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Date 2026-02-19 but 12 - 8 is subtraction.")
    }

    func testPreservesCompactHyphenatedPhoneNumber() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Call me at 480-555-5555.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Call me at 480-555-5555.")
    }

    func testPreservesLocalHyphenatedPhoneNumber() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "555-1234",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "555-1234")
    }

    func testPreservesCompactHyphenatedDateWithShortLeadingSegment() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "2-15-2026",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "2-15-2026")
    }

    func testMathNormalizationIsIdempotentAcrossPipeline() {
        let processor = TranscriptionPostProcessor()
        let first = processor.process(
            "12 plus 8 and 3 squared equals 9 and 50 percent",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )
        let second = processor.process(
            first,
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(first, second)
    }

    func testStripsTerminalPunctuationForStandaloneMathUtterance() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "12 plus 8.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "12 + 8")
    }

    func testPreservesTerminalPunctuationWhenMathIsInSentence() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Please compute 12 plus 8.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Please compute 12 + 8.")
    }

    func testStripsQuestionMarkForStandaloneMathUtterance() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "3 squared equals 9?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "3^2 = 9")
    }
}
