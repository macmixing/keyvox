/// The word being typed and the words before it, read from the text before the cursor.
public struct TypingTextContext: Sendable, Equatable {
    /// Letters and apostrophes immediately before the cursor.
    public let currentWord: String
    /// Earlier words in the same sentence, newest first, at most three.
    public let previousWords: [String]
    /// No earlier words in the current sentence.
    public var isAtSentenceStart: Bool { previousWords.isEmpty }

    public init(textBeforeCursor: String?) {
        let text = textBeforeCursor ?? ""
        var cursor = text.endIndex
        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            guard Self.isWordCharacter(text[previous]) else { break }
            cursor = previous
        }
        currentWord = String(text[cursor...])

        let earlier = text[..<cursor]
        let sentence: Substring
        if let boundary = earlier.lastIndex(where: Self.isSentenceBoundary) {
            sentence = earlier[earlier.index(after: boundary)...]
        } else {
            sentence = earlier
        }
        let words = sentence
            .split { Self.isWordCharacter($0) == false }
            .map(String.init)
        previousWords = Array(words.reversed().prefix(3))
    }

    static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "'" || character == "’"
    }

    private static func isSentenceBoundary(_ character: Character) -> Bool {
        character.isNewline || character == "." || character == "!" || character == "?"
    }
}
