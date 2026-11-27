import Foundation
import KeyVoxTypingLanguageCatalog

extension TypingLanguageCatalog {
    /// The typing languages this package bundles, with the letter layouts each offers.
    public static func bundled() throws -> TypingLanguageCatalog {
        guard let predictiveData = KeyVoxPredictiveKeyboardResources.bundle.url(
            forResource: "PredictiveData",
            withExtension: nil
        ) else {
            throw PredictiveKeyboardError.missingArtifact("PredictiveData")
        }
        return try TypingLanguageCatalog(predictiveDataURL: predictiveData)
    }
}
