import KeyVoxLinguistics
import Foundation

/// Writes a spoken colon, or a word the transcriber heard in its place, as a colon. The word
/// stays a word when it is one of the user's dictionary words, belongs to a listed phrase that
/// names the body part, follows a word that needs a noun after it, or ends a phrase that what
/// follows needs as its subject, and when nothing comes before or after it in its sentence.
public struct ColonNormalizer {
    private struct WordToken {
        let text: String
        let range: Range<String.Index>
        let role: LexicalRole?
    }

    private static let namePhrases = try? PunctuationNamePhrases()
    private static let writtenName = "colon"
    private static let collapsedWhitespaceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s{2,}"#,
        options: []
    )

    public init() {}

    public func normalize(in text: String, dictionaryEntries: [DictionaryEntry] = []) -> String {
        guard !text.isEmpty else { return text }

        let words = wordTokens(in: text)
        let replacements = words.indices.reversed().compactMap { index -> Range<String.Index>? in
            guard isSpokenColon(at: index, words: words, text: text, dictionaryEntries: dictionaryEntries) else {
                return nil
            }
            return replacementRange(for: words[index].range, in: text)
        }
        guard !replacements.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        var replacedFrom = text.endIndex
        for range in replacements where range.upperBound <= replacedFrom {
            mutable.replaceCharacters(in: NSRange(range, in: text), with: ": ")
            replacedFrom = range.lowerBound
        }
        let normalized = mutable as String

        guard let collapsedWhitespaceRegex = Self.collapsedWhitespaceRegex else {
            return stripTerminalPunctuationForShortStandaloneAssociation(in: normalized)
        }
        let collapsed = collapsedWhitespaceRegex.stringByReplacingMatches(
            in: normalized,
            options: [],
            range: NSRange(location: 0, length: (normalized as NSString).length),
            withTemplate: " "
        )
        return stripTerminalPunctuationForShortStandaloneAssociation(in: collapsed)
    }

    private func isSpokenColon(
        at index: Int,
        words: [WordToken],
        text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Bool {
        let word = words[index]
        guard isColonHomophone(word.text),
              !beginsDictionaryEntry(at: word.range, in: text, dictionaryEntries: dictionaryEntries),
              Self.namePhrases?.phraseRange(around: word.range, named: Self.writtenName, in: text) == nil else {
            return false
        }

        if index > words.startIndex {
            let previousIndex = words.index(before: index)
            if isAdjacent(words[previousIndex], words[index], in: text) {
                // A word that needs a noun after it would be left without one, as in "the colon"
                // or "between colon".
                switch words[previousIndex].role {
                case .determiner, .preposition:
                    return false
                default:
                    break
                }
                if opensNounPhrase(endingAt: previousIndex, words: words, text: text),
                   index + 1 < words.endIndex,
                   isAdjacent(words[index], words[index + 1], in: text),
                   words[index + 1].role == .verb || words[index + 1].role == .preposition {
                    return false
                }
            }
        }

        return hasSentenceContent(before: word.range, in: text)
            && hasSentenceContent(after: word.range, in: text)
    }

    /// Whether the descriptive words ending at `index` follow a determiner within one phrase.
    private func opensNounPhrase(endingAt index: Int, words: [WordToken], text: String) -> Bool {
        var current = index
        while current > words.startIndex {
            switch words[current].role {
            case .adjective, .noun, .number, .ordinal:
                break
            default:
                return false
            }

            let previous = words.index(before: current)
            guard isAdjacent(words[previous], words[current], in: text) else { return false }
            if words[previous].role == .determiner {
                return true
            }
            current = previous
        }
        return false
    }

    private func isAdjacent(_ first: WordToken, _ second: WordToken, in text: String) -> Bool {
        text[first.range.upperBound..<second.range.lowerBound].allSatisfy(\.isWhitespace)
    }

    private func beginsDictionaryEntry(
        at range: Range<String.Index>,
        in text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Bool {
        let suffix = text[range.lowerBound...]
        for entry in dictionaryEntries {
            let phrase = entry.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty,
                  let match = suffix.range(
                      of: phrase,
                      options: [.anchored, .caseInsensitive, .diacriticInsensitive]
                  ) else {
                continue
            }
            guard match.upperBound < suffix.endIndex else { return true }
            let nextCharacter = suffix[match.upperBound]
            if !nextCharacter.isLetter, !nextCharacter.isNumber, nextCharacter != "_" {
                return true
            }
        }
        return false
    }

    /// Whether any letter or digit comes between the sentence start and the replaced span.
    private func hasSentenceContent(before range: Range<String.Index>, in text: String) -> Bool {
        let start = replacementRange(for: range, in: text).lowerBound
        for character in text[..<start].reversed() {
            if isSentenceBoundary(character) { return false }
            if character.isLetter || character.isNumber { return true }
        }
        return false
    }

    /// Whether any letter or digit comes between the replaced span and the sentence end.
    private func hasSentenceContent(after range: Range<String.Index>, in text: String) -> Bool {
        let end = replacementRange(for: range, in: text).upperBound
        for character in text[end...] {
            if isSentenceBoundary(character) { return false }
            if character.isLetter || character.isNumber { return true }
        }
        return false
    }

    /// The spoken colon with the space and one comma before it and the commas, periods, and
    /// spaces after it, which the written colon replaces.
    private func replacementRange(for range: Range<String.Index>, in text: String) -> Range<String.Index> {
        var start = range.lowerBound
        while start > text.startIndex {
            let previous = text.index(before: start)
            if text[previous].isWhitespace {
                start = previous
                continue
            }
            if text[previous] == "," {
                start = previous
            }
            break
        }

        var end = range.upperBound
        while end < text.endIndex, text[end] == "," || text[end] == "." || text[end].isWhitespace {
            end = text.index(after: end)
        }
        return start..<end
    }

    private func isSentenceBoundary(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?" || character.isNewline
    }

    private func stripTerminalPunctuationForShortStandaloneAssociation(in text: String) -> String {
        guard !text.contains("\n") else { return text }
        guard text.filter({ $0 == ":" }).count == 1 else { return text }
        guard let colonIndex = text.firstIndex(of: ":") else { return text }

        let lhs = text[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = text[text.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lhs.isEmpty, !rhs.isEmpty else { return text }

        let rhsWithoutTerminalPunctuation = rhs.replacingOccurrences(
            of: #"[.!?…]+["'”’\)\]\}]*\s*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rhsWithoutTerminalPunctuation.isEmpty else { return text }

        let lhsWords = lhs.split(whereSeparator: \.isWhitespace).count
        let rhsWords = rhsWithoutTerminalPunctuation.split(whereSeparator: \.isWhitespace).count
        guard (1...4).contains(lhsWords), (1...5).contains(rhsWords) else { return text }

        return text.replacingOccurrences(
            of: #"[.!?…]+(["'”’\)\]\}]*\s*)$"#,
            with: "$1",
            options: .regularExpression
        )
    }

    private func wordTokens(in text: String) -> [WordToken] {
        TextLinguistics.analyze(text, features: [.roles, .wordBoundaries]).tokens.compactMap { token in
            guard let range = Range(token.range, in: text) else { return nil }
            return WordToken(text: String(text[range]), range: range, role: token.role)
        }
    }

    private func isColonHomophone(_ token: String) -> Bool {
        let letters = token.lowercased().unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let simplified = String(String.UnicodeScalarView(letters))
        guard simplified.hasPrefix("col"), simplified.hasSuffix("n") else { return false }
        guard (4...6).contains(simplified.count) else { return false }
        return levenshteinDistance(between: simplified, and: "colon") <= 1
    }

    private func levenshteinDistance(between lhs: String, and rhs: String) -> Int {
        if lhs == rhs { return 0 }
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1
            for (j, rhsChar) in rhsChars.enumerated() {
                let substitutionCost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + substitutionCost
                )
            }
            swap(&previous, &current)
        }
        return previous[rhsChars.count]
    }
}
