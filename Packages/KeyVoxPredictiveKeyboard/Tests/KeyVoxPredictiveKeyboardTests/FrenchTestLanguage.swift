import XCTest
@testable import KeyVoxPredictiveKeyboard

extension TypingLanguage {
    /// The bundled French language.
    static let french: TypingLanguage = {
        do {
            return try TypingLanguage.bundled(identifier: "fr")
        } catch {
            fatalError("the bundled French typing language did not load: \(error)")
        }
    }()
}
