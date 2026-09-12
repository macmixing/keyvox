import Foundation
import XCTest
@testable import KeyVoxLinguistics

final class LinguisticAnalyzerFactoryTests: XCTestCase {
    func testHealthyPreferredAnalyzerDoesNotResolvePortableResources() {
        let resourceRequests = FactoryLockedCounter()
        let analyzer = LinguisticAnalyzerFactory.healthRouted(
            preferred: FactoryFixedAnalyzer { text, features in
                LinguisticAnalysis(
                    tokens: [Self.token(in: text, role: .noun)],
                    availableFeatures: features
                )
            },
            portableResourceDirectory: {
                resourceRequests.increment()
                return nil
            },
            portableLanguageCode: "en",
            diagnosticHandler: { _ in }
        )

        _ = analyzer.analyze(
            #function,
            range: nil,
            languageCode: nil,
            features: [.roles, .wordBoundaries],
            grouping: .words
        )

        XCTAssertEqual(resourceRequests.value, 0)
    }

    func testUnhealthyPreferredAnalyzerLoadsPortableResources() throws {
        let word = String(UnicodeScalar(0x03B1)!)
        let resources = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Self.writePortableResources(to: resources, knownWord: word)
        defer { try? FileManager.default.removeItem(at: resources) }

        let analyzer = LinguisticAnalyzerFactory.healthRouted(
            preferred: FactoryFixedAnalyzer { text, features in
                LinguisticAnalysis(
                    tokens: [Self.token(in: text, role: .otherWord)],
                    availableFeatures: features
                )
            },
            portableResourceDirectory: { resources },
            portableLanguageCode: "en",
            diagnosticHandler: { _ in }
        )

        let result = analyzer.analyze(
            word,
            range: nil,
            languageCode: "en-US",
            features: [.roles, .wordBoundaries],
            grouping: .words
        )

        XCTAssertEqual(result.tokens.first?.role, .noun)
    }

    func testConfiguredPortableLanguageIsUnavailableForDifferentRequestLanguage() {
        let resourceRequests = FactoryLockedCounter()
        let text = #function
        let analyzer = LinguisticAnalyzerFactory.healthRouted(
            preferred: FactoryFixedAnalyzer { text, features in
                LinguisticAnalysis(
                    tokens: [Self.token(in: text, role: .otherWord)],
                    availableFeatures: features
                )
            },
            portableResourceDirectory: {
                resourceRequests.increment()
                return nil
            },
            portableLanguageCode: "en_US",
            diagnosticHandler: { _ in }
        )

        let result = analyzer.analyze(
            text,
            range: nil,
            languageCode: "fr-CA",
            features: [.roles, .wordBoundaries],
            grouping: .words
        )

        XCTAssertEqual(result.tokens.first?.role, .otherWord)
        XCTAssertEqual(resourceRequests.value, 0)
    }

    private static func token(in text: String, role: LexicalRole) -> LinguisticToken {
        LinguisticToken(
            range: NSRange(text.startIndex..<text.endIndex, in: text),
            role: role,
            identity: .ordinaryWord
        )
    }

    private static func writePortableResources(to resources: URL, knownWord: String) throws {
        let fileManager = FileManager.default
        let model = resources.appendingPathComponent("averaged-perceptron-tagger-eng", isDirectory: true)
        let lexicalDatabase = resources.appendingPathComponent("wordnet-3.0", isDirectory: true)
        try fileManager.createDirectory(at: model, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: lexicalDatabase, withIntermediateDirectories: true)

        try Data(
            #"{"schema":"nltk-perceptron-v1","tagSet":"penn-treebank","languages":["en"],"weights":"weights.json","classes":"classes.json","tagDictionary":"tags.json"}"#.utf8
        ).write(to: model.appendingPathComponent("model.json"))
        try Data(#"{}"#.utf8).write(to: model.appendingPathComponent("weights.json"))
        try Data(#"["NN"]"#.utf8).write(to: model.appendingPathComponent("classes.json"))
        try JSONEncoder().encode([knownWord: "NN"]).write(to: model.appendingPathComponent("tags.json"))

        for filename in ["index.noun", "index.verb", "index.adj", "index.adv"] {
            try Data().write(to: lexicalDatabase.appendingPathComponent(filename))
        }
    }
}

private struct FactoryFixedAnalyzer: LinguisticAnalyzing {
    let result: @Sendable (String, LinguisticFeatures) -> LinguisticAnalysis

    func analyze(
        _ text: String,
        range: NSRange?,
        languageCode: String?,
        features: LinguisticFeatures,
        grouping: LinguisticGrouping
    ) -> LinguisticAnalysis {
        result(text, features)
    }
}

private final class FactoryLockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int { lock.withLock { storage } }

    func increment() {
        lock.withLock { storage += 1 }
    }
}
