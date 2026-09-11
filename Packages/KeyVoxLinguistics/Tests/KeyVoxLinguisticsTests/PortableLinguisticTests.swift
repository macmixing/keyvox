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

        let sentenceCapital = word.uppercased()
        let sentenceKnown = try PerceptronModel(
            weights: [:],
            knownTags: [word: verb],
            classes: [noun, verb]
        )
        XCTAssertEqual(sentenceKnown.tags(for: [sentenceCapital]), [verb])
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

    func testAmbiguousModelLabelsResolveFromStructuralContext() {
        XCTAssertEqual(PennContextualRoleResolver.role(for: "TO", at: 0, tags: ["TO", "VB"]), .particle)
        XCTAssertEqual(PennContextualRoleResolver.role(for: "TO", at: 0, tags: ["TO", "NN"]), .preposition)
        XCTAssertEqual(PennContextualRoleResolver.role(for: "IN", at: 0, tags: ["IN", "PRP", "VBD"]), .conjunction)
        XCTAssertEqual(PennContextualRoleResolver.role(for: "IN", at: 0, tags: ["IN", "DT", "NN"]), .preposition)
        XCTAssertEqual(PennContextualRoleResolver.role(for: "PRP$", at: 0, tags: ["PRP$", "NN"]), .determiner)
        XCTAssertEqual(PennContextualRoleResolver.role(for: "VBG", at: 0, tags: ["VBG", "NN"]), .noun)
    }

    func testPennNounTagsExposeInflectionWithoutFabricatedLemmas() {
        XCTAssertEqual(PennLexicalRole.inflection(for: "NN"), .singular)
        XCTAssertEqual(PennLexicalRole.inflection(for: "NNP"), .singular)
        XCTAssertEqual(PennLexicalRole.inflection(for: "NNS"), .plural)
        XCTAssertEqual(PennLexicalRole.inflection(for: "NNPS"), .plural)
        XCTAssertEqual(PennLexicalRole.inflection(for: "VB"), .unknown)
    }

    func testPerceptronDoesNotExposeUnrequestedRolesOrInflection() throws {
        let lowercase = String(UnicodeScalar(0x03B1)!)
        let word = lowercase.uppercased()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"schema":"nltk-perceptron-v1","tagSet":"penn-treebank","languages":["en"],"weights":"weights.json","classes":"classes.json","tagDictionary":"tags.json"}"#.utf8)
            .write(to: directory.appendingPathComponent("model.json"))
        try Data(#"{}"#.utf8).write(to: directory.appendingPathComponent("weights.json"))
        try Data(#"["NN"]"#.utf8).write(to: directory.appendingPathComponent("classes.json"))
        try JSONEncoder().encode([lowercase: "NN"]).write(to: directory.appendingPathComponent("tags.json"))

        let analyzer = try PerceptronLinguisticAnalyzer(modelDirectory: directory, languageCode: "en")
        let result = analyzer.analyze(
            word,
            range: nil,
            languageCode: "en",
            features: [.names, .wordBoundaries],
            grouping: .words
        )
        XCTAssertEqual(result.availableFeatures, [.names, .wordBoundaries])
        XCTAssertEqual(result.tokens.first?.identity, .name)
        XCTAssertNil(result.tokens.first?.role)
        XCTAssertEqual(result.tokens.first?.inflection, .unknown)
    }

    func testPerceptronUsesHostSelectedDefaultLanguageWhenCallOmitsLanguage() throws {
        let word = String(UnicodeScalar(0x03B1)!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"schema":"nltk-perceptron-v1","tagSet":"penn-treebank","languages":["en"],"weights":"weights.json","classes":"classes.json","tagDictionary":"tags.json"}"#.utf8)
            .write(to: directory.appendingPathComponent("model.json"))
        try Data(#"{}"#.utf8).write(to: directory.appendingPathComponent("weights.json"))
        try Data(#"["NN"]"#.utf8).write(to: directory.appendingPathComponent("classes.json"))
        try JSONEncoder().encode([word: "NN"]).write(to: directory.appendingPathComponent("tags.json"))

        let analyzer = try PerceptronLinguisticAnalyzer(modelDirectory: directory, languageCode: "en")
        let result = analyzer.analyze(
            word,
            range: nil,
            languageCode: nil,
            features: [.roles, .wordBoundaries],
            grouping: .words
        )

        XCTAssertEqual(result.availableFeatures, [.roles, .wordBoundaries])
        XCTAssertEqual(result.tokens.first?.role, .noun)
    }

    func testModelLanguageIdentifiersRequireStructuralLanguageTags() {
        XCTAssertEqual(ModelLanguageIdentifier.base("en-US"), "en")
        XCTAssertEqual(ModelLanguageIdentifier.base("EN_US"), "en")
        for invalid in ["", " ", "en US", "en-", "en\n", "123", "-en"] {
            XCTAssertNil(ModelLanguageIdentifier.base(invalid))
        }
    }
}
