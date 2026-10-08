/// How a suggested word is written: with the typed word's capitalization carried over, and
/// the pronoun "I", alone or contracted ("i'm"), always capitalized.
public enum WordCasing {
    public static func apply(of typedWord: String, to suggestion: String) -> String {
        capitalizingPronoun(carryingCapitalization(of: typedWord, to: suggestion))
    }

    private static func carryingCapitalization(of typedWord: String, to suggestion: String) -> String {
        let letters = typedWord.filter(\.isLetter)
        guard letters.isEmpty == false else { return suggestion }
        if letters.count > 1, letters == letters.uppercased(), letters != letters.lowercased() {
            return suggestion.uppercased()
        }
        guard letters.first?.isUppercase == true, let first = suggestion.first else {
            return suggestion
        }
        return first.uppercased() + suggestion.dropFirst()
    }

    /// `word` written as the first word of a sentence.
    public static func startingSentence(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }

    /// `word` with the pronoun "I", alone or contracted, capitalized.
    public static func capitalizingPronoun(_ word: String) -> String {
        let rest = word.dropFirst()
        guard word.first == "i", rest.isEmpty || rest.first == "'" || rest.first == "’" else {
            return word
        }
        return "I" + rest
    }
}
