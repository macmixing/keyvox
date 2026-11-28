/// How the sentence before a new one ended, with that sentence's words: what the suggestion
/// bar goes by where a sentence begins. Read the way the language data is built
/// (`sentences_with_endings` in Tools/KeyVoxLanguageModel/normalize.py): the last period,
/// question mark, or exclamation mark before the new sentence names its ending, and a line
/// break names it only when no mark comes before it.
public struct SentenceEnding: Sendable, Hashable {
    public enum Mark: String, Sendable, CaseIterable {
        case period
        case question
        case exclamation
        case lineBreak
    }

    public let mark: Mark
    /// The sentence's words in order, lowercased, with typed apostrophes written straight.
    public let words: [String]

    public var firstWord: String { words[0] }

    /// - Precondition: `words` is not empty.
    public init(mark: Mark, words: [String]) {
        precondition(words.isEmpty == false, "a sentence ending needs its sentence's words")
        self.mark = mark
        self.words = words
    }

    /// The sentence that ends where the last sentence of `text` begins, or nil when no
    /// earlier sentence with words ends there.
    /// - Parameter rules: How the typing language's text is read (`TypingLanguage.textRules`).
    public init?(before text: String, rules: TypingTextRules = .standard) {
        let text = text[...]
        var index = TypingTextContext.sentenceStart(in: text, rules: rules)
        var mark: Mark?
        var endsAtLineBreak = false
        while index > text.startIndex {
            let previous = text.index(before: index)
            let character = text[previous]
            if TypingTextContext.isSentenceBoundary(at: previous, in: text, rules: rules) {
                if character.isNewline {
                    endsAtLineBreak = true
                } else if mark == nil {
                    mark = Self.mark(for: character)
                }
            } else if character.isWhitespace == false {
                break
            }
            index = previous
        }
        guard let mark = mark ?? (endsAtLineBreak ? .lineBreak : nil) else { return nil }

        let sentence = text[TypingTextContext.sentenceStart(in: text[..<index], rules: rules)..<index]
        let words = sentence
            .split { rules.isWordCharacter($0) == false }
            .map { rules.straightApostrophes(in: $0.lowercased()) }
        guard words.isEmpty == false else { return nil }
        self.init(mark: mark, words: words)
    }

    private static func mark(for character: Character) -> Mark? {
        switch character {
        case ".": .period
        case "?": .question
        case "!": .exclamation
        default: nil
        }
    }
}
