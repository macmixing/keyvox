import Foundation
import XCTest
@testable import KeyVoxCore

@MainActor
extension TranscriptionPostProcessorTests {
    func testFormatsStandaloneFourDigitQuantitiesBelowTenThousand() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "5600 2000 4000 9300 2100",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "5,600 2,000 4,000 9,300 2,100")
    }

    func testFormatsFourDigitQuantitiesInSentenceWhilePreservingYearReferences() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I shipped 5600 units in 2025 and 9300 units in 2026",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I shipped 5,600 units in 2025 and 9,300 units in 2026")
    }

    func testPreservesYearModifiersWhileFormattingFourDigitQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The 2025 roadmap replaced the 2026 plan after 2100 tickets came in",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The 2025 roadmap replaced the 2026 plan after 2,100 tickets came in")
    }

    func testFormatsPartitiveFourDigitQuantitiesWithoutTreatingThemAsYears() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Can you give me about 2000 of them? I need 1000 of them.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Can you give me about 2,000 of them? I need 1,000 of them.")
    }

    func testPreservesYearReferenceBeforeConfirmationPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Yeah, that came out in 2001, right?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Yeah, that came out in 2001, right?")
    }

    func testFormatsQuantityBeforeConfirmationPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I need 1000, right?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I need 1,000, right?")
    }

    func testPreservesUncertainSentenceFinalYearReference() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I can't remember when that was. I think it was maybe 1993.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I can't remember when that was. I think it was maybe 1993.")
    }

    func testPreservesYearFirstSlashedDatesWhileFormattingQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The deadline is 2026/02/19 and we shipped 5600 units.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The deadline is 2026/02/19 and we shipped 5,600 units.")
    }

    func testFormatsQuantityLikePluralNounPhrasesAtSentenceStartAndAfterDeterminer() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "2000 units shipped yesterday. The 2000 units were backordered.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "2,000 units shipped yesterday. The 2,000 units were backordered."
        )
    }

    func testDoesNotGroupLocalPhoneNumberTailAfterHyphenSpacing() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "555-1234",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "555-1234")
    }

    func testPreservesMonthLedDatesAfterDateNormalization() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "May 15, 1992 and 5000 units.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "May 15, 1992 and 5,000 units.")
    }

    func testNormalizesStandaloneSpokenThousandsQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Five thousand seven hundred and ninety one.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "5,791.")
    }

    func testNormalizesSpokenThousandsAndHundredsWithoutTriggeringListFormatting() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand seventy one.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,071.")
    }

    func testNormalizesSpokenThousandsWithConjunctionAndTeenTailWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand and seventy one.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,071.")
    }

    func testNormalizesSpokenThousandsWithConjunctionAndUnitTailWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand and seventy two.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,072.")
    }

    func testNormalizesLowercasedSpokenThousandsWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "three thousand seventy one",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,071")
    }

    func testNormalizesSpokenThousandsWithFiftyOneTailWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Five thousand fifty one.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "5,051.")
    }

    func testNormalizesSpokenHundredsOverOneThousand() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Thirty five hundred.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "3,500.")
    }

    func testNormalizesSpokenThousandWithAndRemainder() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "One thousand and five.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "1,005.")
    }

    func testNormalizesSpokenThousandsInsideSentenceWithoutTouchingDates() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I need five thousand tickets by May 15, 1992 and three thousand seventy one units after that.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "I need 5,000 tickets by May 15, 1992 and 3,071 units after that."
        )
    }
}
