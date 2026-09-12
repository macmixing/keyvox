import Foundation
import KeyVoxCore
import KeyVoxLinguistics

enum CoreProcessing {
    private struct TokenReport: Encodable {
        let location: Int
        let length: Int
        let role: String?
        let identity: String
        let inflection: String
    }

    private struct Report: Encodable {
        let input: String
        let output: String
        let processingLanguageCode: String?
        let detectedLanguageCode: String?
        let dictionaryEntryCount: Int
        let dictionaryLoadWarning: String?
        let dictionarySaveError: String?
        let dictionaryDegradedDurability: Bool
        let linguisticFeatures: [String: Bool]
        let linguisticTokenCount: Int
        let lexicalRoleCount: Int
        let linguisticTokens: [TokenReport]
        let linguisticImplementation: String
    }

    static func run(text: String, languageCode: String?, detectedLanguageCode: String? = nil) async throws {
        let analyzer: any LinguisticAnalyzing
        if let modelPath = ProcessInfo.processInfo.environment["KEYVOX_LINGUISTIC_MODEL"] {
            let lexicalDatabasePath = ProcessInfo.processInfo.environment["KEYVOX_LEXICAL_DATABASE"]
            analyzer = try PerceptronLinguisticAnalyzer(
                modelDirectory: URL(fileURLWithPath: modelPath),
                lexicalDatabaseDirectory: lexicalDatabasePath.map(URL.init(fileURLWithPath:)),
                languageCode: languageCode
            )
        } else {
            analyzer = TextLinguistics.provider
        }
        let analysis = analyzer.analyze(text, range: nil, languageCode: languageCode,
                                        features: [.roles, .lemmas, .names, .wordBoundaries], grouping: .words)
        let dictionary = await HarnessDictionary.load()
        let output = await TranscriptionPostProcessor(linguisticAnalyzer: analyzer).processAsync(
            text, dictionaryEntries: dictionary.entries, renderMode: .multiline,
            listFormattingEnabled: true, forceAllCaps: false, languageCode: languageCode
        )
        let report = Report(input: text, output: output, processingLanguageCode: languageCode,
                            detectedLanguageCode: detectedLanguageCode, dictionaryEntryCount: dictionary.entries.count,
                            dictionaryLoadWarning: dictionary.loadWarning, dictionarySaveError: dictionary.saveError,
                            dictionaryDegradedDurability: dictionary.degradedDurability,
                            linguisticFeatures: [
                                "roles": analysis.availableFeatures.contains(.roles),
                                "lemmas": analysis.availableFeatures.contains(.lemmas),
                                "names": analysis.availableFeatures.contains(.names),
                                "wordBoundaries": analysis.availableFeatures.contains(.wordBoundaries),
                            ], linguisticTokenCount: analysis.tokens.count,
                            lexicalRoleCount: analysis.tokens.filter { $0.role != nil }.count,
                            linguisticTokens: analysis.tokens.map {
                                TokenReport(location: $0.range.location, length: $0.range.length,
                                            role: $0.role.map { String(describing: $0) },
                                            identity: String(describing: $0.identity),
                                            inflection: String(describing: $0.inflection))
                            },
                            linguisticImplementation: modelPathDescription())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    }

    private static func modelPathDescription() -> String {
        guard ProcessInfo.processInfo.environment["KEYVOX_LINGUISTIC_MODEL"] != nil else {
            return "platform-default"
        }
        return ProcessInfo.processInfo.environment["KEYVOX_LEXICAL_DATABASE"] == nil
            ? "perceptron"
            : "perceptron+wordnet-3.0"
    }
}
