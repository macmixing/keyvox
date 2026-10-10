/// Suggestions computed for one prediction request.
public struct PredictionResult: Sendable, Equatable {
    /// What the keyboard knows the current word as, which decides what keeping it as typed
    /// teaches the keyboard.
    public enum TypedWordKind: Sendable, Equatable {
        /// A word the bundled dictionary has, or the counts show in everyday use, including a
        /// known name the dictionary has as an everyday word, such as a contact named "Rose".
        case dictionaryWord
        /// One of the user's own words: a dictionary entry, a known name the dictionary lacks,
        /// or a text replacement shortcut.
        case usersWord
        /// Neither, as a name or brand the keyboard is learning, or has learned, from the user.
        case unknown
    }

    public let request: PredictionRequest
    public let bar: SuggestionBar
    /// What space should insert in place of the current word, already in the typed case.
    public let autocorrection: String?
    /// What the keyboard knows the current word as; a dictionary word between words.
    public var typedWordKind: TypedWordKind = .dictionaryWord
}
