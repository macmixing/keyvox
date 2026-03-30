import Foundation
import XCTest
@testable import KeyVoxCore

@MainActor
extension TranscriptionPostProcessorTests {
    func testNormalizesSpokenMonthOrdinalAndYearDateForms() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            """
            March thirteenth, twenty twenty five.
            April tenth, twenty twenty-two.
            December fifteenth, nineteen eighty-five.
            January second, two thousand five.
            May fifth, nineteen ninety-five.
            March thirty first, nineteen seventy one.
            """,
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            March 13, 2025.
            April 10, 2022.
            December 15, 1985.
            January 2, 2005.
            May 5, 1995.
            March 31, 1971.
            """
        )
    }

    func testNormalizesMonthDayYearNumericAndOrdinalDateForms() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            """
            March 13th, 2025.
            April 10th, 2022.
            December 15th 1985.
            January 2nd 2,005.
            May 5, 1,995.
            March 31, 1,971.
            """,
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertEqual(
            output,
            """
            March 13, 2025.
            April 10, 2022.
            December 15, 1985.
            January 2, 2005.
            May 5, 1995.
            March 31, 1971.
            """
        )
    }

    func testPreservesQuantitiesWhileNormalizingMonthLedDates() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "March 13th, 2025 and 2100 tickets. April tenth, twenty twenty-two and 5000 units.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(
            output,
            "March 13, 2025 and 2,100 tickets. April 10, 2022 and 5,000 units."
        )
    }
}
