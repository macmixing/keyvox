import Foundation
import Dispatch
import XCTest
import KeyVoxLinguistics
import KeyVoxCorePackageDiscoveredTests

private final class MeasuredAnalyzer: LinguisticAnalyzing, @unchecked Sendable {
    private let base: PerceptronLinguisticAnalyzer
    private let lock = NSLock()
    private var calls = 0

    init(directory: URL, language: String) throws {
        base = try PerceptronLinguisticAnalyzer(modelDirectory: directory, languageCode: language)
    }

    func analyze(_ text: String, range: NSRange?, languageCode: String?,
                 features: LinguisticFeatures, grouping: LinguisticGrouping) -> LinguisticAnalysis {
        let count = lock.withLock { calls += 1; return calls }
        if count == 1 {
            FileHandle.standardError.write(Data("Explicit model analyzer invoked\n".utf8))
        }
        return base.analyze(text, range: range, languageCode: languageCode, features: features, grouping: grouping)
    }
}

@main
struct ModelSelectedRunner {
    enum Failure: Error { case missingConfiguration }
    static func main() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["KEYVOX_LINGUISTIC_MODEL"],
              let language = environment["KEYVOX_LINGUISTIC_LANGUAGE"] else {
            throw Failure.missingConfiguration
        }
        let analyzer = try MeasuredAnalyzer(directory: URL(fileURLWithPath: path), language: language)
        TextLinguistics.$provider.withValue(analyzer) {
            XCTMain(__allDiscoveredTests())
        }
    }
}
