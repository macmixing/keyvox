import KeyVoxPredictiveKeyboard

/// The language the keyboard types in: its letter layout, quotation marks, casing, and the
/// files its suggestions and corrections come from.
enum KeyboardTypingLanguage {
    /// The bundled language the keyboard types in. Its files are compiled into the typing
    /// package, so it always loads in a correctly built keyboard.
    static let current: TypingLanguage = {
        do {
            return try TypingLanguage.bundled(identifier: "en")
        } catch {
            preconditionFailure("the bundled typing language did not load: \(error)")
        }
    }()
}
