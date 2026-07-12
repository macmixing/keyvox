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

        XCTAssertEqual(output, "I shipped 5,600 units in 2025 and 9,300 units in 2026.")
    }

    func testPreservesYearModifiersWhileFormattingFourDigitQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The 2025 roadmap replaced the 2026 plan after 2100 tickets came in",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The 2025 roadmap replaced the 2026 plan after 2,100 tickets came in.")
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

    func testPreservesSpokenSinceYearWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Yo, I haven't seen her since two thousand twelve.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Yo, I haven't seen her since 2012.")
    }

    func testPreservesSpokenSinceLikeYearWithoutGroupingSeparator() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I haven't seen her since like two thousand twelve.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I haven't seen her since like 2012.")
    }

    func testPreservesSpokenYearBeforeConfirmationPhrase() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm pretty sure that movie came out in two thousand twelve. What do you think?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I'm pretty sure that movie came out in 2012. What do you think?")
    }

    func testPreservesAdjacentSpokenYearsWithoutGroupingSeparators() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The audit started in two thousand eighteen and wrapped up in two thousand nineteen.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "The audit started in 2018 and wrapped up in 2019.")
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

    func testFormatsSpokenQuantityWithYearLikeValueWhenContextIsQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I need two thousand twelve tickets and one thousand five labels.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I need 2,012 tickets and 1,005 labels.")
    }

    func testFormatsSpokenQuantityAfterFillerLikeWhenContextIsQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I need like two thousand twelve tickets.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I need like 2,012 tickets.")
    }

    func testPreservesSpokenYearWhileFormattingNearbySpokenQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I haven't seen her since two thousand twelve, but I still need five thousand tickets.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "I haven't seen her since 2012, but I still need 5,000 tickets.")
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

    func testPreservesMonthYearReferencesWhileFormattingFourDigitQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "November 2025 had 5000 signups.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "November 2025 had 5,000 signups.")
    }

    func testPreservesFourDigitAddressNumbersWithoutGroupingSeparators() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Meet me at 1152 North Washington Street. Drop it at 1925 South Franklin Boulevard.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "Meet me at 1152 North Washington Street. Drop it at 1925 South Franklin Boulevard."
        )
    }

    func testPreservesAddressNumbersWhileFormattingNearbyQuantities() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Send 5600 flyers to 1034 West General Street by 3:30.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Send 5,600 flyers to 1034 West General Street by 3:30.")
    }

    func testNormalizesStandaloneSpokenThousandsQuantity() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Five thousand seven hundred and ninety one.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "5,791")
    }

    func testNormalizesSpokenThousandsAndHundredsWithoutTriggeringListFormatting() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand seventy one.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,071")
    }

    func testNormalizesSpokenThousandsWithConjunctionAndTeenTailWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand and seventy one.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,071")
    }

    func testNormalizesSpokenThousandsWithConjunctionAndUnitTailWithoutLeavingResidualWords() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Three thousand and seventy two.",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(output, "3,072")
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

        XCTAssertEqual(output, "5,051")
    }

    func testNormalizesSpokenHundredsOverOneThousand() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Thirty five hundred.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "3,500")
    }

    func testNormalizesSpokenThousandWithAndRemainder() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "One thousand and five.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "1,005")
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
