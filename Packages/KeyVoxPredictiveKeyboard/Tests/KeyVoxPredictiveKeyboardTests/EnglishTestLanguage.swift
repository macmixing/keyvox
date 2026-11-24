import XCTest
@testable import KeyVoxPredictiveKeyboard

extension TypingLanguage {
    /// The bundled English language the tests type in.
    static let english: TypingLanguage = {
        do {
            return try TypingLanguage.bundled(identifier: "en")
        } catch {
            fatalError("the bundled English typing language did not load: \(error)")
        }
    }()
}
