import XCTest
@testable import KeyVoxTTS

final class PocketTTSSpokenNumberNormalizerTests: XCTestCase {
    func testNormalizeSpeaksSellerCounterAmounts() {
        let normalized = PocketTTSChunkPlanner.normalize(
            "Seller countered: $46,000 / $8k down / 30 months"
        )

        XCTAssertTrue(
            normalized.text.hasSuffix(
                "Seller countered. forty-six thousand dollars slash eight thousand dollars down slash 30 months."
            )
        )
    }

    func testNormalizeSpeaksStandaloneGroupedThousands() {
        XCTAssertEqual(
            PocketTTSSpokenNumberNormalizer.normalize(in: "46,532"),
            "forty-six thousand five hundred thirty-two"
        )
    }

    func testNormalizeSpeaksStandaloneGroupedMillionsAndBillions() {
        let examples = [
            "1,236,456": "one million two hundred thirty-six thousand four hundred fifty-six",
            "1,236,456,789": "one billion two hundred thirty-six million four hundred fifty-six thousand seven hundred eighty-nine",
        ]

        for (input, expected) in examples {
            XCTAssertEqual(
                PocketTTSSpokenNumberNormalizer.normalize(in: input),
                expected
            )
        }
    }

    func testNormalizeSpeaksStandaloneCompactThousands() {
        let examples = [
            "8k": "eight thousand",
            "12K": "twelve thousand",
        ]

        for (input, expected) in examples {
            XCTAssertEqual(
                PocketTTSSpokenNumberNormalizer.normalize(in: input),
                expected
            )
        }
    }

    func testNormalizeSpeaksDollarAmounts() {
        let examples = [
            "$46,532": "forty-six thousand five hundred thirty-two dollars",
            "$1,236,456": "one million two hundred thirty-six thousand four hundred fifty-six dollars",
            "$1,236,456,789": "one billion two hundred thirty-six million four hundred fifty-six thousand seven hundred eighty-nine dollars",
            "$46532": "forty-six thousand five hundred thirty-two dollars",
            "$8k": "eight thousand dollars",
            "$12K": "twelve thousand dollars",
        ]

        for (input, expected) in examples {
            XCTAssertEqual(
                PocketTTSSpokenNumberNormalizer.normalize(in: input),
                expected
            )
        }
    }

    func testNormalizeHandlesSentencePunctuation() {
        XCTAssertEqual(
            PocketTTSSpokenNumberNormalizer.normalize(in: "Totals: 46,532, then $1,236,456."),
            "Totals: forty-six thousand five hundred thirty-two, then one million two hundred thirty-six thousand four hundred fifty-six dollars."
        )
    }

    func testNormalizeLeavesDecimalsPercentagesAndYearsUnchanged() {
        let input = "$12.50 46,532.75 46,532% 2026"
        XCTAssertEqual(PocketTTSSpokenNumberNormalizer.normalize(in: input), input)
    }
}
