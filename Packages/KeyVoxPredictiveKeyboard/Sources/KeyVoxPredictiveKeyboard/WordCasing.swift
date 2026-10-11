/// How a suggested word is written: with the typed word's capitalization carried over, and
/// the pronoun "I", alone or contracted ("i'm"), always capitalized.
public enum WordCasing {
    public static func apply(of typedWord: String, to suggestion: String) -> String {
        capitalizingPronoun(carryingCapitalization(of: typedWord, to: suggestion))
    }

    /// `word` in capitals when `typedWord`, of more than one letter, was typed all in capitals,
    /// as with caps lock on.
    public static func carryingAllCapitals(of typedWord: String, to word: String) -> String {
        isAllCapitals(typedWord) ? word.uppercased() : word
    }

    private static func carryingCapitalization(of typedWord: String, to suggestion: String) -> String {
        if isAllCapitals(typedWord) {
            return suggestion.uppercased()
        }
        guard typedWord.first(where: \.isLetter)?.isUppercase == true, let first = suggestion.first else {
            return suggestion
        }
        return first.uppercased() + suggestion.dropFirst()
    }

    private static func isAllCapitals(_ typedWord: String) -> Bool {
        let letters = typedWord.filter(\.isLetter)
        return letters.count > 1 && letters == letters.uppercased() && letters != letters.lowercased()
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
