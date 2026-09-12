import Foundation
import KeyVoxLinguistics
import XCTest
@testable import KeyVoxCore

final class PortableNumericTextProtectionTests: XCTestCase {
    func testReportsBothCapabilitiesWhenNoSpanMatches() {
        let result = PortableNumericTextProtection().analyze(String(UnicodeScalar(0x03B1)!))
        XCTAssertTrue(result.ranges.isEmpty)
        XCTAssertTrue(result.isComplete)
    }

    func testProtectsNumericAndLocaleMonthDates() throws {
        let year = String(2_026)
        let numeric = [year, String(2), String(19)].joined(separator: "/")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let month = try XCTUnwrap(formatter.monthSymbols.first)
        let written = month + " " + String(19) + ", " + year

        XCTAssertFalse(PortableNumericTextProtection().analyze(numeric).ranges.isEmpty)
        XCTAssertFalse(PortableNumericTextProtection().analyze(written).ranges.isEmpty)
    }

    func testProtectsStructuralTitledAddressButNotOrdinaryQuantity() {
        let scalarWords = [0x0391, 0x0392, 0x0393].map { String(UnicodeScalar($0)!) + String(UnicodeScalar(0x03B1)!) }
        let address = String(1_034) + " " + scalarWords.prefix(2).joined(separator: " ")
        let quantity = String(5_600) + " " + scalarWords[0]

        XCTAssertFalse(PortableNumericTextProtection().analyze(address).ranges.isEmpty)
        XCTAssertTrue(PortableNumericTextProtection().analyze(quantity).ranges.isEmpty)
    }

    func testDoesNotProtectTwoTitledQuantityModifiersInsideProse() {
        let titleWords = [0x0391, 0x0392].map {
            String(UnicodeScalar($0)!) + String(UnicodeScalar(0x03B1)!)
        }
        let lowercaseHead = String(UnicodeScalar(0x03B3)!) + String(UnicodeScalar(0x03B1)!)
        let text = ([String(5_600)] + titleWords + [lowercaseHead]).joined(separator: " ")

        XCTAssertTrue(PortableNumericTextProtection().analyze(text).ranges.isEmpty)
    }

    func testGroupsTerminalTitledQuantityWhenSemanticHeadIsPlural() throws {
        let digits = String(5_600)
        let titleWords = [0x0391, 0x0392].map {
            String(UnicodeScalar($0)!) + String(UnicodeScalar(0x03B1)!)
        }
        let candidate = ([digits] + titleWords).joined(separator: " ")
        let text = candidate + String(UnicodeScalar(0x002E)!)
        let lowercasedCandidate = candidate.lowercased()
        let analyzer = try AddressSemanticAnalyzer(analyses: [
            text: [
                token(digits, in: text, role: .number),
                token(titleWords[0], in: text, role: .noun, inflection: .singular),
                token(titleWords[1], in: text, role: .noun, inflection: .singular),
            ],
            lowercasedCandidate: [
                token(digits, in: lowercasedCandidate, role: .number),
                token(titleWords[0].lowercased(), in: lowercasedCandidate, role: .noun, inflection: .singular),
                token(titleWords[1].lowercased(), in: lowercasedCandidate, role: .noun, inflection: .plural),
            ],
        ])
        let normalizer = ThousandsGroupingNormalizer(protectionAnalyzer: PortableNumericTextProtection())

        let output = TextLinguistics.$provider.withValue(analyzer) {
            normalizer.normalize(in: text)
        }

        XCTAssertEqual(output, normalizer.normalize(in: digits) + String(text.dropFirst(digits.count)))
    }

    func testGroupsQuantityBeforeThreeTitledModifiersAndNominalHead() throws {
        let digits = String(5_600)
        let titleWords = [0x0391, 0x0392, 0x0393].map {
            String(UnicodeScalar($0)!) + String(UnicodeScalar(0x03B1)!)
        }
        let nominalHead = String(UnicodeScalar(0x03B4)!) + String(UnicodeScalar(0x03B1)!)
        let candidate = ([digits] + titleWords).joined(separator: " ")
        let text = candidate + " " + nominalHead
        let lowercasedCandidate = candidate.lowercased()
        let analyzer = try AddressSemanticAnalyzer(analyses: [
            text: [
                token(digits, in: text, role: .number),
                token(titleWords[0], in: text, role: .noun, inflection: .singular),
                token(titleWords[1], in: text, role: .noun, inflection: .singular),
                token(titleWords[2], in: text, role: .noun, inflection: .singular),
                token(nominalHead, in: text, role: .noun, inflection: .plural),
            ],
            lowercasedCandidate: [
                token(digits, in: lowercasedCandidate, role: .number),
                token(titleWords[0].lowercased(), in: lowercasedCandidate, role: .adjective),
                token(titleWords[1].lowercased(), in: lowercasedCandidate, role: .noun, inflection: .singular),
                token(titleWords[2].lowercased(), in: lowercasedCandidate, role: .noun, inflection: .singular),
            ],
        ])
        let normalizer = ThousandsGroupingNormalizer(protectionAnalyzer: PortableNumericTextProtection())

        let output = TextLinguistics.$provider.withValue(analyzer) {
            normalizer.normalize(in: text)
        }

        XCTAssertEqual(output, normalizer.normalize(in: digits) + String(text.dropFirst(digits.count)))
    }

    func testProtectsAddressWhenNextNounBeginsAfterPunctuationBoundary() throws {
        let digits = String(5_600)
        let titleWords = [0x0391, 0x0392].map {
            String(UnicodeScalar($0)!) + String(UnicodeScalar(0x03B1)!)
        }
        let nextNoun = String(UnicodeScalar(0x0393)!) + String(UnicodeScalar(0x03B1)!)
        let candidate = ([digits] + titleWords).joined(separator: " ")
        let text = candidate + String(UnicodeScalar(0x002E)!) + " " + nextNoun
        let lowercasedCandidate = candidate.lowercased()
        let analyzer = try AddressSemanticAnalyzer(analyses: [
            text: [
                token(digits, in: text, role: .number),
                token(titleWords[0], in: text, role: .noun, inflection: .singular),
                token(titleWords[1], in: text, role: .noun, inflection: .singular),
                token(nextNoun, in: text, role: .noun, inflection: .plural),
            ],
            lowercasedCandidate: [
                token(digits, in: lowercasedCandidate, role: .number),
                token(titleWords[0].lowercased(), in: lowercasedCandidate, role: .noun, inflection: .singular),
                token(titleWords[1].lowercased(), in: lowercasedCandidate, role: .noun, inflection: .singular),
            ],
        ])
        let protection = TextLinguistics.$provider.withValue(analyzer) {
            PortableNumericTextProtection().analyze(text)
        }

        XCTAssertEqual(protection.ranges, [NSRange(location: 0, length: (candidate as NSString).length)])
    }

    func testProtectsAddressWhenNextNounBeginsAfterNewlineBoundary() throws {
        let digits = String(5_600)
        let titleWords = [0x0391, 0x0392].map {
            String(UnicodeScalar($0)!) + String(UnicodeScalar(0x03B1)!)
        }
        let nextNoun = String(UnicodeScalar(0x03B3)!) + String(UnicodeScalar(0x03B1)!)
        let candidate = ([digits] + titleWords).joined(separator: " ")
        let text = candidate + "\n" + nextNoun
        let lowercasedCandidate = candidate.lowercased()
        let analyzer = try AddressSemanticAnalyzer(analyses: [
            text: [
                token(digits, in: text, role: .number),
                token(titleWords[0], in: text, role: .noun, inflection: .singular),
                token(titleWords[1], in: text, role: .noun, inflection: .singular),
                token(nextNoun, in: text, role: .noun, inflection: .plural),
            ],
            lowercasedCandidate: [
                token(digits, in: lowercasedCandidate, role: .number),
                token(titleWords[0].lowercased(), in: lowercasedCandidate, role: .noun, inflection: .singular),
                token(titleWords[1].lowercased(), in: lowercasedCandidate, role: .noun, inflection: .singular),
            ],
        ])
        let protection = TextLinguistics.$provider.withValue(analyzer) {
            PortableNumericTextProtection().analyze(text)
        }

        XCTAssertEqual(protection.ranges, [NSRange(location: 0, length: (candidate as NSString).length)])
    }

    func testDoesNotJoinAddressWordsAcrossNewlineBoundary() {
        let digits = String(5_600)
        let titleWords = [0x0391, 0x0392].map {
            String(UnicodeScalar($0)!) + String(UnicodeScalar(0x03B1)!)
        }
        let text = digits + "\n" + titleWords.joined(separator: " ")

        XCTAssertTrue(PortableNumericTextProtection().analyze(text).ranges.isEmpty)
    }

    private func token(
        _ word: String,
        in text: String,
        role: LexicalRole,
        inflection: LinguisticToken.Inflection = .unknown
    ) throws -> LinguisticToken {
        let range = try XCTUnwrap(text.range(of: word))
        return LinguisticToken(
            range: NSRange(range, in: text),
            role: role,
            inflection: inflection
        )
    }
}

private struct AddressSemanticAnalyzer: LinguisticAnalyzing {
    let analyses: [String: [LinguisticToken]]

    func analyze(
        _ text: String,
        range: NSRange?,
        languageCode: String?,
        features: LinguisticFeatures,
        grouping: LinguisticGrouping
    ) -> LinguisticAnalysis {
        guard let tokens = analyses[text] else {
            return UnicodeLinguisticAnalyzer().analyze(
                text,
                range: range,
                languageCode: languageCode,
                features: features,
                grouping: grouping
            )
        }
        return LinguisticAnalysis(
            tokens: tokens,
            availableFeatures: [.roles, .wordBoundaries]
        )
    }
}
