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
}
