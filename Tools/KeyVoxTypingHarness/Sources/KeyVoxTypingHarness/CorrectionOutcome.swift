/// What happened to one typed word when space was pressed.
struct CorrectionOutcome {
    enum TypingKind {
        /// The simulated finger produced exactly the intended word.
        case exact
        /// Every letter landed, but the intended contraction needs its apostrophe restored.
        case missingApostrophe
        /// At least one tap resolved to the wrong key.
        case mistyped
    }

    let intendedWord: String
    let typedWord: String
    let previousWords: [String]
    let suggestions: [String]
    let typedWordIsValid: Bool
    let automaticCorrectionProbability: Double
    let correction: String?
    let reason: String

    var finalWord: String { correction ?? typedWord }

    var isFinalWordCorrect: Bool {
        finalWord.lowercased() == intendedWord
    }

    var typingKind: TypingKind {
        if typedWord == intendedWord { return .exact }
        if typedWord == intendedWord.replacingOccurrences(of: "'", with: "") {
            return .missingApostrophe
        }
        return .mistyped
    }

    /// 1-based position of the intended word in the engine's ranked list, if present.
    var intendedRank: Int? {
        suggestions.firstIndex { $0.lowercased() == intendedWord }.map { $0 + 1 }
    }
}
