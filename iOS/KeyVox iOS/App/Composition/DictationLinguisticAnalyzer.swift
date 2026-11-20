import Foundation
import KeyVoxLinguistics

/// Builds the linguistic analyzer every dictation process shares the configuration of.
nonisolated enum DictationLinguisticAnalyzer {
    /// - Parameter portableResourceDirectory: Where the containing app's bundled fallback
    ///   resources are, as seen from the calling process.
    static func make(portableResourceDirectory: @escaping @Sendable () -> URL?) -> any LinguisticAnalyzing {
        LinguisticAnalyzerFactory.healthRouted(
            portableResourceDirectory: portableResourceDirectory,
            portableLanguageCode: "en"
        )
    }
}
