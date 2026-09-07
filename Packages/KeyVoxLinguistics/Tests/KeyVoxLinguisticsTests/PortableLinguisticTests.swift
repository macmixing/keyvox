import Foundation
import XCTest
@testable import KeyVoxLinguistics

final class PortableLinguisticTests: XCTestCase {
    func testUnicodeBoundariesPreserveOriginalUTF16Coordinates() {
        let first = String(UnicodeScalar(0x03B1)!)
        let second = String(UnicodeScalar(0x0431)!)
        let prefix = String(UnicodeScalar(0x1F4CD)!) + " "
        let text = prefix + first + " " + second
        let analyzer = UnicodeLinguisticAnalyzer()
        let result = analyzer.analyze(text, range: nil, languageCode: nil,
                                      features: [.roles, .lemmas, .names, .wordBoundaries], grouping: .words)
        XCTAssertEqual(result.tokens.map(\.range), [NSRange(location: prefix.utf16.count, length: first.utf16.count),
                                                   NSRange(location: prefix.utf16.count + first.utf16.count + 1, length: second.utf16.count)])
        XCTAssertEqual(result.availableFeatures, [.wordBoundaries])
        XCTAssertTrue(result.tokens.allSatisfy { $0.role == nil && $0.lemma == nil && $0.identity == .unknown })
        let limited = analyzer.analyze(text, range: result.tokens[1].range, languageCode: nil,
                                      features: [.wordBoundaries], grouping: .words)
        XCTAssertEqual(limited.tokens.count, 1)
        XCTAssertEqual(limited.tokens[0].range, result.tokens[1].range)
    }

    func testPerceptronUsesContextAndDeterministicTieBreaking() throws {
        let word = String(UnicodeScalar(0x03B1)!)
        let noun = "NN", verb = "VB"
        let tied = try PerceptronModel(weights: [:], knownTags: [:], classes: [verb, noun])
        XCTAssertEqual(tied.tags(for: [word]), [max(verb, noun)])
        let known = try PerceptronModel(weights: [:], knownTags: [word: noun], classes: [noun, verb])
        XCTAssertEqual(known.tags(for: [word]), [noun])
        let context = try PerceptronModel(weights: ["i-1 tag " + noun: [verb: 2]],
                                          knownTags: [word: noun], classes: [noun, verb])
        XCTAssertEqual(context.tags(for: [word, word + word]), [noun, verb])
    }

    func testInvalidModelsAndOverflowNeverReportPredictions() throws {
        XCTAssertThrowsError(try PerceptronModel(weights: [:], knownTags: [:], classes: []))
        XCTAssertThrowsError(try PerceptronModel(weights: [:], knownTags: [:], classes: ["NN", "NN"]))
        XCTAssertThrowsError(try PerceptronModel(weights: ["bias": ["NN": .infinity]], knownTags: [:], classes: ["NN"]))
        XCTAssertThrowsError(try PerceptronModel(weights: [:], knownTags: ["": "VB"], classes: ["NN"]))
        let word = String(UnicodeScalar(0x03B1)!)
        let model = try PerceptronModel(weights: ["bias": ["NN": .greatestFiniteMagnitude],
                                                  "i word " + word: ["NN": .greatestFiniteMagnitude]],
                                        knownTags: [:], classes: ["NN"])
        XCTAssertNil(model.tags(for: [word]))
    }

    func testModelNormalizationUsesUnicodeDigitProperties() {
        let digits = String(repeating: String(UnicodeScalar(0x0661)!), count: 4)
        XCTAssertEqual(PerceptronFeatures.normalize(digits), "!YEAR")
        XCTAssertEqual(PerceptronFeatures.normalize(String(digits.prefix(1))), "!DIGITS")
    }

    func testAmbiguousModelLabelsDoNotClaimSemanticPrepositions() {
        XCTAssertNil(PennLexicalRole.role(for: "IN"))
        XCTAssertNil(PennLexicalRole.role(for: "TO"))
        XCTAssertEqual(PennLexicalRole.role(for: "NNP"), .noun)
    }

    func testModelLanguageIdentifiersRequireStructuralLanguageTags() {
        XCTAssertEqual(ModelLanguageIdentifier.base("en-US"), "en")
        XCTAssertEqual(ModelLanguageIdentifier.base("EN_US"), "en")
        for invalid in ["", " ", "en US", "en-", "en\n", "123", "-en"] {
            XCTAssertNil(ModelLanguageIdentifier.base(invalid))
        }
    }
}
