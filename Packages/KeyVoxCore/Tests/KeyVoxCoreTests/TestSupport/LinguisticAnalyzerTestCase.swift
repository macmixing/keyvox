import Foundation
import KeyVoxLinguistics
import XCTest

class LinguisticAnalyzerTestCase: XCTestCase {
    override func invokeTest() {
        TextLinguistics.$provider.withValue(Self.provider) {
            super.invokeTest()
        }
    }

    private static let provider: any LinguisticAnalyzing = {
        let environment = ProcessInfo.processInfo.environment
        guard let modelPath = environment["KEYVOX_LINGUISTIC_MODEL"],
              let languageCode = environment["KEYVOX_LINGUISTIC_LANGUAGE"] else {
            return TextLinguistics.provider
        }

        let lexicalDatabaseDirectory = environment["KEYVOX_LEXICAL_DATABASE"]
            .map(URL.init(fileURLWithPath:))

        do {
            return try PerceptronLinguisticAnalyzer(
                modelDirectory: URL(fileURLWithPath: modelPath),
                lexicalDatabaseDirectory: lexicalDatabaseDirectory,
                languageCode: languageCode
            )
        } catch {
            fatalError("Unable to configure the requested linguistic test analyzer: \(error)")
        }
    }()
}
