import KeyVoxLinguistics
import Foundation

/// Writes a spoken colon, or a word the transcriber heard in its place, as a colon. The word
/// stays a word when it is part of a hyphenated word or one of the user's dictionary entries,
/// belongs to a listed phrase that names the body part, addresses a person after a phrase that
/// opens with a greeting, farewell, or thanks, follows a word that needs a
/// noun after it, or ends a phrase opened by a determiner where its sentence ends or what follows
/// needs it as a noun, and when nothing comes before it in its sentence or after it, unless it
/// ends the dictation after other words or stands as a sentence of its own after a sentence,
/// which the transcriber split at the spoken colon.
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
        let replacements = words.indices.reversed().compactMap { index -> Range<String.Index>? in
            spokenColonRange(at: index, words: words, text: text, dictionaryEntries: dictionaryEntries)
        }
        guard !replacements.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        var replacedFrom = text.endIndex
        for range in replacements where range.upperBound <= replacedFrom {
            let lineBreaks = text[range].filter(\.isNewline)
            let separator = range.upperBound == text.endIndex ? "" : (lineBreaks.isEmpty ? " " : String(lineBreaks))
            mutable.replaceCharacters(in: NSRange(range, in: text), with: ":" + separator)
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
        let range = words[index].range
        if hasSentenceContent(before: range, in: text) {
            if hasSentenceContent(after: range, in: text) {
                return replacementRange(for: range, in: text)
            }
            // A colon ending the dictation introduces what the speaker sends next.
            let replacement = replacementRange(for: range, in: text)
            return replacement.upperBound == text.endIndex ? replacement : nil
        }
        return ownSentenceReplacementRange(for: range, in: text)
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
              !addressesPerson(word.range, in: text) else {
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

    /// The span from the period ending the sentence before the word through the punctuation and
    /// spaces after it, when the word is a sentence of its own after a sentence, either between two
    /// sentences or at the end of the dictation.
    private func ownSentenceReplacementRange(
        for range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index>? {
        var start = range.lowerBound
        while start > text.startIndex, text[text.index(before: start)].isWhitespace,
              !text[text.index(before: start)].isNewline {
            start = text.index(before: start)
        }
        guard start > text.startIndex else { return nil }
        let periodIndex = text.index(before: start)
        guard text[periodIndex] == ".",
              hasSentenceContent(before: periodIndex..<start, in: text) else {
            return nil
        }

        let end = replacementRange(for: range, in: text).upperBound
        guard end == text.endIndex
                || (text[range.upperBound..<end].contains(where: isSentenceBoundary)
                    && text[end...].contains(where: { $0.isLetter || $0.isNumber })) else {
            return nil
        }
        return periodIndex..<end
    }

    /// Whether the word is a name spoken to someone after a phrase that opens with a greeting,
    /// farewell, or thanks, as in "thank you so much for the help, Colin" or "okay, goodbye,
    /// Colin", where the phrase runs back from the word to the comma before it or the start of
    /// its sentence.
    private func addressesPerson(_ range: Range<String.Index>, in text: String) -> Bool {
        guard let greetingPhrases = Self.greetingPhrases else { return false }
        var phraseEnd = range.lowerBound
        while phraseEnd > text.startIndex, text[text.index(before: phraseEnd)].isWhitespace {
            phraseEnd = text.index(before: phraseEnd)
        }
        if phraseEnd > text.startIndex, text[text.index(before: phraseEnd)] == "," {
            phraseEnd = text.index(before: phraseEnd)
        }
        var phraseStart = phraseEnd
        while phraseStart > text.startIndex {
            let previous = text[text.index(before: phraseStart)]
            if isSentenceBoundary(previous) || previous == "," { break }
            phraseStart = text.index(before: phraseStart)
        }
        return greetingPhrases.startsWithPhrase(text[phraseStart..<phraseEnd])
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
