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
    /// The sentence's words in order, lowercased, with curly apostrophes written straight.
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
    public init?(before text: String) {
        let text = text[...]
        var index = TypingTextContext.sentenceStart(in: text)
        var mark: Mark?
        var endsAtLineBreak = false
        while index > text.startIndex {
            let previous = text.index(before: index)
            let character = text[previous]
            if TypingTextContext.isSentenceBoundary(at: previous, in: text) {
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

        let sentence = text[TypingTextContext.sentenceStart(in: text[..<index])..<index]
        let words = sentence
            .split { TypingTextContext.isWordCharacter($0) == false }
            .map { $0.lowercased().replacingOccurrences(of: "’", with: "'") }
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
