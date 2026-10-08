/// How far back deleting whole words reaches, the way the system keyboard deletes words while
/// delete is held: each word goes with the spaces or line breaks after it, and punctuation
/// written against a word goes with the word.
enum KeyboardWordDeletion {
    struct Span: Equatable {
        let characterCount: Int
        /// How many of the words asked for the text held; fewer when it runs out first.
        let wordCount: Int
    }

    /// The characters at the end of `text` that up to `words` whole words take up.
    static func span(ofWords words: Int, endingText text: String) -> Span {
        var start = text.endIndex
        var wordCount = 0
        while wordCount < words, start > text.startIndex {
            while start > text.startIndex, text[text.index(before: start)].isWhitespace {
                start = text.index(before: start)
            }
            while start > text.startIndex, text[text.index(before: start)].isWhitespace == false {
                start = text.index(before: start)
            }
            wordCount += 1
        }
        return Span(characterCount: text.distance(from: start, to: text.endIndex), wordCount: wordCount)
    }
}
