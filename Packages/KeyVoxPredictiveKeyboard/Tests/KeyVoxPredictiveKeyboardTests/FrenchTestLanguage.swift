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

extension TypingLanguage {
    /// The bundled French (Canada) language.
    static let frenchCanada: TypingLanguage = {
        do {
            return try TypingLanguage.bundled(identifier: "fr-CA")
        } catch {
            fatalError("the bundled French (Canada) typing language did not load: \(error)")
        }
    }()
}
