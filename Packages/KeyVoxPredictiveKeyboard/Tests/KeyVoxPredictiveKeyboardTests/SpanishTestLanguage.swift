import XCTest
@testable import KeyVoxPredictiveKeyboard

extension TypingLanguage {
    /// The bundled Spanish language the tests type in.
    static let spanish: TypingLanguage = {
        do {
            return try TypingLanguage.bundled(identifier: "es")
        } catch {
            fatalError("the bundled Spanish typing language did not load: \(error)")
        }
    }()
}
