import KeyVoxLinguistics
import Foundation

/// Writes a spoken colon, or a word the transcriber heard in its place, as a colon, replacing
/// whatever punctuation the transcriber put on either side of it. The word stays a word when it is
/// part of a hyphenated word or one of the user's dictionary entries, belongs to a listed phrase
/// that names the body part, addresses a person after a phrase that opens with a greeting,
/// farewell, or thanks, follows a word that needs a noun after it, or ends a phrase opened by a
/// determiner where its sentence ends or what follows needs it as a noun, and when nothing comes
/// before it in the dictation.
public struct ColonNormalizer {
    private struct WordToken {
        let text: String
        let range: Range<String.Index>
        let role: LexicalRole?
    }

    private static let namePhrases = try? PunctuationNamePhrases()
    private static let greetingPhrases = try? GreetingPhrases()
    private static let writtenName = "colon"
    private static let collapsedWhitespaceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[^\S\r\n]{2,}"#,
        options: []
    )

    public init() {}

    public func normalize(in text: String, dictionaryEntries: [DictionaryEntry] = []) -> String {
        guard !text.isEmpty else { return text }

        let words = wordTokens(in: text)
        let replacements = words.indices.reversed().compactMap { index -> (word: Range<String.Index>, span: Range<String.Index>)? in
            spokenColonRange(at: index, words: words, text: text, dictionaryEntries: dictionaryEntries)
                .map { (words[index].range, $0) }
        }
        guard !replacements.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        var replacedFrom = text.endIndex
        for replacement in replacements where replacement.span.upperBound <= replacedFrom {
            // The line breaks the transcriber put around the spoken colon still start the next line,
            // taking those after it when it has breaks on both sides.
            let breaksAfter = text[replacement.word.upperBound..<replacement.span.upperBound].filter(\.isNewline)
            let breaksBefore = text[replacement.span.lowerBound..<replacement.word.lowerBound].filter(\.isNewline)
            let lineBreaks = breaksAfter.isEmpty ? breaksBefore : breaksAfter
            let separator = replacement.span.upperBound == text.endIndex
                ? ""
                : (lineBreaks.isEmpty ? " " : String(lineBreaks))
            mutable.replaceCharacters(in: NSRange(replacement.span, in: text), with: ":" + separator)
            replacedFrom = replacement.span.lowerBound
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

    /// The span a written colon replaces when the word at `index` is a spoken colon.
    private func spokenColonRange(
        at index: Int,
        words: [WordToken],
        text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Range<String.Index>? {
        guard isSpokenColon(at: index, words: words, text: text, dictionaryEntries: dictionaryEntries) else {
            return nil
        }
        let replacement = replacementRange(for: words[index].range, in: text)
        // Words must come before the colon in the dictation, and it either ends the dictation,
        // introducing what the speaker sends next, or has words after it.
        guard text[..<replacement.lowerBound].contains(where: isContent),
              replacement.upperBound == text.endIndex || text[replacement.upperBound...].contains(where: isContent) else {
            return nil
        }
        return replacement
    }

    private func isSpokenColon(
        at index: Int,
        words: [WordToken],
        text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Bool {
        let word = words[index]
        guard isColonHomophone(word.text),
              !isHyphenated(word.range, in: text),
              !isInsideDictionaryEntry(word.range, in: text, dictionaryEntries: dictionaryEntries),
              Self.namePhrases?.phraseRange(around: word.range, named: Self.writtenName, in: text) == nil,
              !addressesPerson(replacementRange(for: word.range, in: text), in: text) else {
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
                // A phrase opened by a determiner names the thing when the sentence ends after it,
                // as in "the word colon.", or what follows needs it as a noun, as in "the word
                // colon appears".
                if opensNounPhrase(endingAt: previousIndex, words: words, text: text) {
                    if endsSentence(after: word.range, in: text) {
                        return false
                    }
                    if index + 1 < words.endIndex,
                       isAdjacent(words[index], words[index + 1], in: text),
                       words[index + 1].role == .verb || words[index + 1].role == .preposition {
                        return false
                    }
                }
            }
        }

        return true
    }

    /// Whether the word whose replaced span is `span` is a name spoken to someone after a phrase
    /// that opens with a greeting, farewell, or thanks, as in "thank you so much for the help,
    /// Colin", "okay, goodbye, Colin", or "good morning. Colin", where the phrase runs back from the
    /// punctuation before the word to the comma before it or the start of its sentence.
    private func addressesPerson(_ span: Range<String.Index>, in text: String) -> Bool {
        guard let greetingPhrases = Self.greetingPhrases else { return false }
        var phraseStart = span.lowerBound
        while phraseStart > text.startIndex {
            let previous = text[text.index(before: phraseStart)]
            if isSentenceBoundary(previous) || previous == "," { break }
            phraseStart = text.index(before: phraseStart)
        }
        return greetingPhrases.startsWithPhrase(text[phraseStart..<span.lowerBound])
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

    /// Whether the word is joined to another by a hyphen, as in "semi-colon", so it is part of
    /// that compound word.
    private func isHyphenated(_ range: Range<String.Index>, in text: String) -> Bool {
        (range.lowerBound > text.startIndex && text[text.index(before: range.lowerBound)] == "-")
            || (range.upperBound < text.endIndex && text[range.upperBound] == "-")
    }

    /// Whether the word is part of one of the user's dictionary entries as written in `text`,
    /// wherever it falls in the entry, as in "Kristen Colon".
    private func isInsideDictionaryEntry(
        _ range: Range<String.Index>,
        in text: String,
        dictionaryEntries: [DictionaryEntry]
    ) -> Bool {
        for entry in dictionaryEntries {
            let phrase = entry.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty else { continue }

            var searchStart = text.startIndex
            while let match = text.range(
                of: phrase,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex
            ) {
                if match.lowerBound <= range.lowerBound,
                   match.upperBound >= range.upperBound,
                   isWordBoundary(before: match.lowerBound, in: text),
                   isWordBoundary(after: match.upperBound, in: text) {
                    return true
                }
                guard match.lowerBound < range.lowerBound else { break }
                searchStart = text.index(after: match.lowerBound)
            }
        }
        return false
    }

    private func isWordBoundary(before index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        return !isWordCharacter(text[text.index(before: index)])
    }

    private func isWordBoundary(after index: String.Index, in text: String) -> Bool {
        guard index < text.endIndex else { return true }
        return !isWordCharacter(text[index])
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// Whether only spaces and closing punctuation come between the word and the end of its
    /// sentence.
    private func endsSentence(after range: Range<String.Index>, in text: String) -> Bool {
        for character in text[range.upperBound...] {
            if isSentenceBoundary(character) { return true }
            if character.isLetter || character.isNumber { return false }
        }
        return true
    }

    private func isContent(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    /// The spoken colon with the spaces, line breaks, and separating punctuation the transcriber
    /// put on either side of it, which the written colon replaces.
    private func replacementRange(for range: Range<String.Index>, in text: String) -> Range<String.Index> {
        var start = range.lowerBound
        while start > text.startIndex, isSeparator(text[text.index(before: start)]) {
            start = text.index(before: start)
        }

        var end = range.upperBound
        while end < text.endIndex, isSeparator(text[end]) {
            end = text.index(after: end)
        }
        return start..<end
    }

    /// Whether the character is a space, a line break, a dash, or punctuation that Unicode marks as
    /// ending a sentence or clause, rather than a quote, bracket, or mark that belongs to a word.
    private func isSeparator(_ character: Character) -> Bool {
        if character.isWhitespace { return true }
        return character.unicodeScalars.allSatisfy { $0.properties.isTerminalPunctuation || $0.properties.isDash }
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
