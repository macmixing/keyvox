import Foundation
import KeyVoxCore
import KeyVoxLinguistics

enum CoreProcessing {
    private struct Report: Encodable {
        let input: String
        let output: String
        let processingLanguageCode: String?
        let detectedLanguageCode: String?
        let linguisticFeatures: [String: Bool]
    }

    static func run(text: String, languageCode: String?, detectedLanguageCode: String? = nil) async throws {
        let analysis = TextLinguistics.analyze(text, languageCode: languageCode,
                                             features: [.roles, .lemmas, .names, .wordBoundaries])
        let output = await TranscriptionPostProcessor().processAsync(
            text, dictionaryEntries: [], renderMode: .multiline,
            listFormattingEnabled: true, forceAllCaps: false, languageCode: languageCode
        )
        let report = Report(input: text, output: output, processingLanguageCode: languageCode,
                            detectedLanguageCode: detectedLanguageCode, linguisticFeatures: [
                                "roles": analysis.availableFeatures.contains(.roles),
                                "lemmas": analysis.availableFeatures.contains(.lemmas),
                                "names": analysis.availableFeatures.contains(.names),
                                "wordBoundaries": analysis.availableFeatures.contains(.wordBoundaries),
                            ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    }
}
