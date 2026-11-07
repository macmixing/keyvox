import Foundation

/// Phrases in which the name of a punctuation mark is an ordinary word, such as a kind of
/// period, comma, or colon, drawn from WordNet 3.0 and Wiktionary. A spoken mark name inside
/// one of these phrases names the thing, not the mark.
public struct PunctuationNamePhrases: Sendable {
    public enum Failure: Error { case missingResource }

    private static let resourceName = "punctuation_name_phrases"
    private static let resourceExtension = "txt"

    /// Each listed phrase as its lowercase words.
    private let phrases: [[String]]

    /// The list bundled with this package, found through `KeyVoxLinguisticsResources`.
    public init() throws {
        guard let url = KeyVoxLinguisticsResources.bundle.url(
            forResource: Self.resourceName,
            withExtension: Self.resourceExtension
        ) else {
            throw Failure.missingResource
        }
        try self.init(contentsOf: url)
    }

    public init(contentsOf url: URL) throws {
        let contents = try String(contentsOf: url, encoding: .utf8)
        phrases = contents
            .split(whereSeparator: \.isNewline)
            .map { line in line.split(whereSeparator: \.isWhitespace).map { Self.key($0) } }
            .filter { !$0.isEmpty }
    }

    /// The range of the listed phrase that the mark name at `nameRange` in `text` belongs to,
    /// where `name` is the mark's name in its written form, so a misheard spelling of the name
    /// still matches the phrase.
    public func phraseRange(
        around nameRange: Range<String.Index>,
        named name: String,
        in text: String
    ) -> Range<String.Index>? {
        let nameWords = name.split(whereSeparator: \.isWhitespace).map { Self.key($0) }
        guard !nameWords.isEmpty else { return nil }

        for phrase in phrases where phrase.count > nameWords.count {
            var start = phrase.startIndex
            while start + nameWords.count <= phrase.endIndex {
                defer { start += 1 }
                guard Array(phrase[start..<(start + nameWords.count)]) == nameWords,
                      let lowerBound = startOfWords(
                          of: phrase[..<start],
                          endingAt: nameRange.lowerBound,
                          in: text
                      ),
                      let upperBound = endOfWords(
                          of: phrase[(start + nameWords.count)...],
                          startingAt: nameRange.upperBound,
                          in: text
                      ) else {
                    continue
                }
                return lowerBound..<upperBound
            }
        }
        return nil
    }

    /// Where `words` begin when they come right before `index`, each separated by whitespace.
    private func startOfWords(
        of words: ArraySlice<String>,
        endingAt index: String.Index,
        in text: String
    ) -> String.Index? {
        var current = index
        for word in words.reversed() {
            guard current > text.startIndex, text[text.index(before: current)].isWhitespace else { return nil }
            var wordEnd = text.index(before: current)
            while wordEnd > text.startIndex, text[text.index(before: wordEnd)].isWhitespace {
                wordEnd = text.index(before: wordEnd)
            }
            var wordStart = wordEnd
            while wordStart > text.startIndex, !text[text.index(before: wordStart)].isWhitespace {
                wordStart = text.index(before: wordStart)
            }
            guard Self.key(text[wordStart..<wordEnd]) == word else { return nil }
            current = wordStart
        }
        return current
    }

    /// Where `words` end when they come right after `index`, each separated by whitespace,
    /// allowing punctuation after the last of them.
    private func endOfWords(
        of words: ArraySlice<String>,
        startingAt index: String.Index,
        in text: String
    ) -> String.Index? {
        var current = index
        for (offset, word) in words.enumerated() {
            guard current < text.endIndex, text[current].isWhitespace else { return nil }
            var wordStart = current
            while wordStart < text.endIndex, text[wordStart].isWhitespace {
                wordStart = text.index(after: wordStart)
            }
            var wordEnd = wordStart
            while wordEnd < text.endIndex, !text[wordEnd].isWhitespace {
                wordEnd = text.index(after: wordEnd)
            }
            if offset == words.count - 1 {
                while wordEnd > wordStart, isTrailingPunctuation(text[text.index(before: wordEnd)]) {
                    wordEnd = text.index(before: wordEnd)
                }
            }
            guard Self.key(text[wordStart..<wordEnd]) == word else { return nil }
            current = wordEnd
        }
        return current
    }

    private func isTrailingPunctuation(_ character: Character) -> Bool {
        character.isPunctuation && character != "'" && character != "’"
    }

    /// The list's comparison form of a word: lowercase, with a typographic apostrophe written plainly.
    private static func key<S: StringProtocol>(_ word: S) -> String {
        word.lowercased().replacingOccurrences(of: "’", with: "'")
    }
}
