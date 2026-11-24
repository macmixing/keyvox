/// How a suggested word is written: with the typed word's capitalization carried over, and the
/// typing language's always-capitalized words, alone or before an apostrophe, written as the
/// language writes them.
public struct WordCasing: Sendable {
    /// Each always-capitalized word, lowercased, with how the language writes it.
    private let alwaysCapitalized: [(lowercased: String, written: String)]

    init(alwaysCapitalizedWords: [String]) {
        alwaysCapitalized = alwaysCapitalizedWords.map { ($0.lowercased(), $0) }
    }

    public func apply(of typedWord: String, to suggestion: String) -> String {
        writingAlwaysCapitalized(Self.carryingCapitalization(of: typedWord, to: suggestion))
    }

    /// `word` with an always-capitalized word it is, alone or before an apostrophe, written as
    /// the language writes it.
    public func writingAlwaysCapitalized(_ word: String) -> String {
        for entry in alwaysCapitalized where word.hasPrefix(entry.lowercased) {
            let rest = word.dropFirst(entry.lowercased.count)
            if rest.isEmpty || rest.first == "'" || rest.first == "’" {
                return entry.written + rest
            }
        }
        return word
    }

    /// `word` in capitals when `typedWord`, of more than one letter, was typed all in capitals,
    /// as with caps lock on.
    public static func carryingAllCapitals(of typedWord: String, to word: String) -> String {
        isAllCapitals(typedWord) ? word.uppercased() : word
    }

    /// `word` written as the first word of a sentence.
    public static func startingSentence(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
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
}
