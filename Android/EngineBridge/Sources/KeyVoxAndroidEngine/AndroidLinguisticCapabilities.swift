import Foundation
import CAndroidEngine
import KeyVoxLinguistics

enum AndroidLinguisticCapabilities {
    static func makeAnalyzer(resources: URL) throws -> any LinguisticAnalyzing {
        let linguisticResources = resources.appendingPathComponent("KeyVoxAndroidLinguistics.resources")
        let modelDirectory = linguisticResources.appendingPathComponent("averaged-perceptron-tagger-eng")
        let lexicalDatabaseDirectory = linguisticResources.appendingPathComponent("wordnet-3.0")
        let analyzer = try PerceptronLinguisticAnalyzer(
            modelDirectory: modelDirectory,
            lexicalDatabaseDirectory: lexicalDatabaseDirectory,
            languageCode: "en"
        )
        keyvox_engine_log_info("linguistic-capabilities=perceptron+wordnet-3.0 default-language=en")
        return analyzer
    }
}
