/// The word being typed and the words before it, read from the text around the cursor.
public struct TypingTextContext: Sendable, Equatable {
    /// Letters and apostrophes immediately before the cursor.
    public let currentWord: String
    /// Letters and apostrophes immediately after the cursor: the rest of the word it is in.
    public let restOfWord: String
    /// The selected text, when it is a single word.
    public let selectedWord: String?
    /// The text after the cursor, or after the selection.
    public let followingText: String
    /// Earlier words in the same sentence, newest first, at most three.
    public let previousWords: [String]
    /// No earlier words in the current sentence.
    public var isAtSentenceStart: Bool { previousWords.isEmpty }

    public init(textBeforeCursor: String?, selectedText: String? = nil, textAfterCursor: String? = nil) {
        let text = textBeforeCursor ?? ""
        var cursor = text.endIndex
        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard Self.isWordCharacter(text[previous]) else { break }
            cursor = previous
        }
        currentWord = String(text[cursor...])

        let earlier = text[..<cursor]
        let words = earlier[Self.sentenceStart(in: earlier)...]
            .split { Self.isWordCharacter($0) == false }
            .map(String.init)
        previousWords = Array(words.reversed().prefix(3))

        let selected = selectedText ?? ""
        selectedWord = selected.isEmpty == false && selected.allSatisfy(Self.isWordCharacter) ? selected : nil
        followingText = textAfterCursor ?? ""
        restOfWord = selected.isEmpty ? String(followingText.prefix(while: Self.isWordCharacter)) : ""
    }

    static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "'" || character == "’"
    }

    /// Whether a word typed right after `text` starts a sentence: `text` is empty or ends at
    /// a line break, or at a period, question mark, or exclamation mark that is not part of
    /// an ellipsis, since an ellipsis pauses a sentence rather than ending it.
    public static func startsSentence(after text: String) -> Bool {
        sentenceStart(in: text[...]) == text.endIndex
    }

    /// Where the last sentence of `text` begins: right after its last sentence boundary.
    static func sentenceStart(in text: Substring) -> Substring.Index {
        var index = text.endIndex
        while index > text.startIndex {
            let previous = text.index(before: index)
            if isSentenceBoundary(at: previous, in: text) { return index }
            index = previous
        }
        return text.startIndex
    }

    static func isSentenceBoundary(at index: Substring.Index, in text: Substring) -> Bool {
        let character = text[index]
        if character.isNewline || character == "!" || character == "?" { return true }
        return character == "." && isInEllipsis(at: index, in: text) == false
    }

    /// Whether the period at `index` is one of three or more in a row, the way an ellipsis is
    /// typed ("…" itself never ends a sentence).
    private static func isInEllipsis(at index: Substring.Index, in text: Substring) -> Bool {
        var start = index
        while start > text.startIndex, text[text.index(before: start)] == "." {
            start = text.index(before: start)
        }
        var end = text.index(after: index)
        while end < text.endIndex, text[end] == "." {
            end = text.index(after: end)
        }
        return text.distance(from: start, to: end) >= 3
    }
}
