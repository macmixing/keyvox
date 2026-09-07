import Foundation
import XCTest
@testable import KeyVoxLinguistics
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

final class LinguisticAnalysisTests: XCTestCase {
    func testUTF16LookupUsesOriginalTextCoordinates() throws {
        let text = String(UnicodeScalar(0x1f30d)!) + UUID().uuidString
        let start = text.index(after: text.startIndex)
        let range = NSRange(start..<text.endIndex, in: text)
        let token = LinguisticToken(range: range, role: .noun, identity: .name)
        let analysis = LinguisticAnalysis(tokens: [token], availableFeatures: [.roles, .names])
        XCTAssertNil(analysis.token(atUTF16Offset: range.location - 1))
        XCTAssertEqual(analysis.token(atUTF16Offset: range.location)?.role, .noun)
        XCTAssertEqual(analysis.token(atUTF16Offset: NSMaxRange(range) - 1)?.identity, .name)
        XCTAssertNil(analysis.token(atUTF16Offset: NSMaxRange(range)))
    }

    func testScopedProviderReportsUnavailableFeaturesWithoutGuessing() {
        struct Unavailable: LinguisticAnalyzing {
            func analyze(_ text: String, range: NSRange?, languageCode: String?, features: LinguisticFeatures, grouping: LinguisticGrouping) -> LinguisticAnalysis {
                LinguisticAnalysis(tokens: [], availableFeatures: [])
            }
        }
        TextLinguistics.$provider.withValue(Unavailable()) {
            let result = TextLinguistics.analyze(UUID().uuidString, features: [.roles, .names, .lemmas])
            XCTAssertTrue(result.tokens.isEmpty)
            XCTAssertTrue(result.availableFeatures.isEmpty)
        }
    }

    #if canImport(NaturalLanguage)
    func testAppleLexicalAndLemmaParityWithLocalizedCalendarText() {
        for identifier in ["en_US", "fr_FR", "de_DE", "tr_TR", "ja_JP"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: identifier)
            formatter.dateStyle = .full
            let text = formatter.string(from: Date(timeIntervalSinceReferenceDate: 0))
            let result = TextLinguistics.analyze(text, features: [.roles, .lemmas])
            let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
            tagger.string = text
            var expectedRanges: [NSRange] = []
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
                let expectedRange = NSRange(range, in: text)
                expectedRanges.append(expectedRange)
                let actual = result.token(atUTF16Offset: expectedRange.location)
                XCTAssertEqual(actual?.role, LexicalRole(tag))
                XCTAssertEqual(actual?.lemma, tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue)
                return true
            }
            XCTAssertEqual(result.tokens.map(\.range), expectedRanges)
            for index in text.indices where text[index].isLetter || text[index].isNumber {
                let offset = NSRange(text.startIndex..<index, in: text).length
                XCTAssertEqual(
                    result.token(atUTF16Offset: offset)?.role,
                    LexicalRole(tagger.tag(at: index, unit: .word, scheme: .lexicalClass).0)
                )
            }
        }
    }
    #endif
}
