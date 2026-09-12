import Foundation
import KeyVoxLinguistics
import XCTest
@testable import KeyVoxCore

final class NumericTextProtectionTests: XCTestCase {
    private struct Analyzer: NumericTextProtectionAnalyzing {
        let ranges: [NSRange]
        let available: Set<NumericTextProtection.Category>
        func analyze(_ text: String) -> NumericTextProtection {
            NumericTextProtection(ranges: ranges, availableCategories: available)
        }
    }

    func testUnavailableProtectionKeepsProseButGroupsStandaloneQuantity() {
        let normalizer = ThousandsGroupingNormalizer(protectionAnalyzer: Analyzer(ranges: [], available: []))
        let digits = String(4_321)
        let label = String(UnicodeScalar(0x03B1)!)
        let prose = digits + " " + label
        XCTAssertEqual(normalizer.normalize(in: prose), prose)
        XCTAssertNotEqual(normalizer.normalize(in: digits), digits)
        XCTAssertEqual(normalizer.normalize(in: " \t" + digits + " \t"),
                       " \t" + normalizer.normalize(in: digits) + " \t")
        let year = String(2_024)
        let date = [year, String(12), String(31)].joined(separator: "-")
        XCTAssertEqual(normalizer.normalize(in: date), date)
    }

    func testPartialProtectionDoesNotAuthorizeProseGrouping() {
        let digits = String(4_321)
        let prose = String(UnicodeScalar(0x03B1)!) + " " + digits
        for category in NumericTextProtection.Category.allCases {
            let normalizer = ThousandsGroupingNormalizer(protectionAnalyzer: Analyzer(ranges: [], available: [category]))
            XCTAssertEqual(normalizer.normalize(in: prose), prose)
        }
    }

    func testSuccessfulEmptyDetectionDiffersFromUnavailableAndHonorsRanges() {
        let digits = String(4_321)
        let prefix = String(UnicodeScalar(0x1F4CD)!) + " "
        let text = prefix + digits
        let complete = Set(NumericTextProtection.Category.allCases)
        let noMatch = ThousandsGroupingNormalizer(protectionAnalyzer: Analyzer(ranges: [], available: complete))
        XCTAssertNotEqual(noMatch.normalize(in: text), text)
        let range = NSRange(location: prefix.utf16.count, length: digits.utf16.count)
        let protected = ThousandsGroupingNormalizer(protectionAnalyzer: Analyzer(ranges: [range], available: complete))
        XCTAssertEqual(protected.normalize(in: text), text)
    }

    func testQuantityBeforeAdjectiveAndPluralNounIsGrouped() {
        let digits = String(2_400)
        let modifier = String(UnicodeScalar(0x03B1)!)
        let head = String(UnicodeScalar(0x03B2)!)
        let text = [digits, modifier, head].joined(separator: " ")
        let tokens = [
            LinguisticToken(range: NSRange(location: 0, length: digits.utf16.count), role: .number),
            LinguisticToken(
                range: NSRange(location: digits.utf16.count + 1, length: modifier.utf16.count),
                role: .adjective
            ),
            LinguisticToken(
                range: NSRange(
                    location: digits.utf16.count + modifier.utf16.count + 2,
                    length: head.utf16.count
                ),
                role: .noun,
                inflection: .plural
            ),
        ]
        let protection = Analyzer(ranges: [], available: Set(NumericTextProtection.Category.allCases))
        let normalizer = ThousandsGroupingNormalizer(protectionAnalyzer: protection)
        let output = TextLinguistics.$provider.withValue(FixedLinguisticAnalyzer(tokens: tokens)) {
            normalizer.normalize(in: text)
        }
        XCTAssertEqual(output, [normalizer.normalize(in: digits), modifier, head].joined(separator: " "))
    }

    func testMissingGrammaticalRolesPreservePlausibleYearButGroupLargerQuantity() {
        let word = String(UnicodeScalar(0x03B1)!)
        let year = String(2_019)
        let quantity = String(3_400)
        let text = [word, year, word, quantity, word].joined(separator: " ")
        let protection = Analyzer(ranges: [], available: Set(NumericTextProtection.Category.allCases))
        let normalizer = ThousandsGroupingNormalizer(protectionAnalyzer: protection)
        let output = TextLinguistics.$provider.withValue(UnicodeLinguisticAnalyzer()) {
            normalizer.normalize(in: text)
        }
        XCTAssertEqual(
            output,
            [word, year, word, normalizer.normalize(in: quantity), word].joined(separator: " ")
        )
    }
}

private struct FixedLinguisticAnalyzer: LinguisticAnalyzing {
    let tokens: [LinguisticToken]

    func analyze(
        _ text: String,
        range: NSRange?,
        languageCode: String?,
        features: LinguisticFeatures,
        grouping: LinguisticGrouping
    ) -> LinguisticAnalysis {
        LinguisticAnalysis(tokens: tokens, availableFeatures: [.roles, .wordBoundaries])
    }
}
