import Foundation
import NaturalLanguage

public struct TerminalPunctuationNormalizer {
    private struct WordToken {
        let text: String
        let range: Range<String.Index>
        let lexicalClass: NLTag?
    }

    private struct CommandMatch {
        let firstWordIndex: Int
        let nextWordIndex: Int
        let symbols: String
    }

    private enum SpokenCommand {
        static let questionMark = ["question", "mark"]
        static let exclamationPoint = ["exclamation", "point"]
        static let exclamationMark = ["exclamation", "mark"]
    }

    private static let terminalTimeRegex = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[1-9]|1[0-2]):[0-5][0-9]\s(?:AM|PM)\s*$"#
    )
    private static let terminalSentencePunctuationRegex = try? NSRegularExpression(
        pattern: #"[.!?…][\"'”’\)\]\}]*\s*$"#
    )

    public init() {}

    public func normalizeSpokenTerminalPunctuation(in text: String) -> String {
        guard !text.isEmpty else { return text }

        let words = wordTokens(in: text)
        guard !words.isEmpty else { return text }
        let commandMatches = terminalCommandMatches(in: words, text: text)
            .filter { isEligibleCommand(match: $0, words: words, text: text) }
        guard !commandMatches.isEmpty else { return text }

        var normalized = text
        for commandMatch in commandMatches.reversed() {
            let replacementRange = replacementRange(for: commandMatch, words: words, text: normalized)
            normalized.replaceSubrange(replacementRange, with: commandMatch.symbols)
        }
        return normalized
    }

    func hasTerminalSentencePunctuation(_ text: String) -> Bool {
        guard let regex = Self.terminalSentencePunctuationRegex else { return false }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    public func appendTerminalPeriodIfEndingInFormattedTime(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        // Respect existing terminal punctuation, including punctuation before closing quotes/brackets.
        if hasTerminalSentencePunctuation(text) {
            return text
        }

        guard let regex = Self.terminalTimeRegex else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return text
        }

        // Only treat this as sentence-like if there is prose before the terminal time.
        let prefix = nsText.substring(to: match.range.location)
        guard prefix.range(of: #"\b[A-Za-z]{3,}\b"#, options: .regularExpression) != nil else {
            return text
        }

        return text + "."
    }

    private func wordTokens(in text: String) -> [WordToken] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var tokens: [WordToken] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let lexicalClass = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0
            tokens.append(WordToken(text: String(text[range]), range: range, lexicalClass: lexicalClass))
            return true
        }

        return tokens
    }

    private func terminalCommandMatches(in words: [WordToken], text: String) -> [CommandMatch] {
        var matches: [CommandMatch] = []
        var startIndex = words.startIndex

        while startIndex < words.endIndex {
            var currentIndex = startIndex
            var symbols = ""

            while currentIndex < words.count {
                guard let command = commandSymbol(startingAt: currentIndex, in: words, text: text) else {
                    break
                }

                symbols += command.symbol
                currentIndex = command.nextIndex
            }

            if !symbols.isEmpty, isTerminalBoundary(afterWordAt: currentIndex - 1, nextWordIndex: currentIndex, words: words, text: text) {
                matches.append(CommandMatch(firstWordIndex: startIndex, nextWordIndex: currentIndex, symbols: symbols))
                startIndex = currentIndex
            } else {
                startIndex = words.index(after: startIndex)
            }
        }

        return matches
    }

    private func commandSymbol(
        startingAt index: Int,
        in words: [WordToken],
        text: String
    ) -> (symbol: String, nextIndex: Int)? {
        if matches(SpokenCommand.questionMark, startingAt: index, in: words, text: text) {
            return ("?", index + SpokenCommand.questionMark.count)
        }

        if matches(SpokenCommand.exclamationPoint, startingAt: index, in: words, text: text)
            || matches(SpokenCommand.exclamationMark, startingAt: index, in: words, text: text) {
            return ("!", index + SpokenCommand.exclamationPoint.count)
        }

        return nil
    }

    private func matches(
        _ phrase: [String],
        startingAt index: Int,
        in words: [WordToken],
        text: String
    ) -> Bool {
        guard index + phrase.count <= words.count else { return false }

        for offset in phrase.indices {
            let wordIndex = index + offset
            guard words[wordIndex].text.lowercased() == phrase[offset] else { return false }
            if offset > phrase.startIndex {
                guard isWhitespaceOnly(text[words[wordIndex - 1].range.upperBound..<words[wordIndex].range.lowerBound]) else {
                    return false
                }
            }
        }

        return true
    }

    private func isEligibleCommand(match: CommandMatch, words: [WordToken], text: String) -> Bool {
        guard match.firstWordIndex > words.startIndex else { return true }

        let previousIndex = words.index(before: match.firstWordIndex)
        let previousWord = words[previousIndex]
        let leadingBoundary = text[previousWord.range.upperBound..<words[match.firstWordIndex].range.lowerBound]
        if leadingBoundary.contains(where: isCommandSentenceBoundary) || leadingBoundary.contains(where: \.isNewline) {
            return true
        }

        if previousWord.lexicalClass == .determiner {
            return false
        }

        if previousWord.lexicalClass == .conjunction,
           commandPhraseEndsBeforeWord(at: previousIndex, words: words, text: text) {
            return false
        }

        if match.firstWordIndex == 2 {
            let secondPreviousWord = words[words.index(before: previousIndex)]
            if secondPreviousWord.lexicalClass == .determiner, previousWord.lexicalClass == .noun {
                return false
            }
        }

        if previousIndex > words.startIndex, previousWord.lexicalClass == .verb {
            return false
        }

        return true
    }

    private func commandPhraseEndsBeforeWord(
        at index: Int,
        words: [WordToken],
        text: String
    ) -> Bool {
        matches(SpokenCommand.questionMark, endingBefore: index, in: words, text: text)
            || matches(SpokenCommand.exclamationPoint, endingBefore: index, in: words, text: text)
            || matches(SpokenCommand.exclamationMark, endingBefore: index, in: words, text: text)
    }

    private func matches(
        _ phrase: [String],
        endingBefore index: Int,
        in words: [WordToken],
        text: String
    ) -> Bool {
        let startIndex = index - phrase.count
        guard startIndex >= words.startIndex,
              matches(phrase, startingAt: startIndex, in: words, text: text) else {
            return false
        }

        let phraseEndIndex = words.index(before: index)
        let gap = text[words[phraseEndIndex].range.upperBound..<words[index].range.lowerBound]
        return wordTokens(in: String(gap)).isEmpty
    }

    private func isTerminalBoundary(
        afterWordAt wordIndex: Int,
        nextWordIndex: Int,
        words: [WordToken],
        text: String
    ) -> Bool {
        if nextWordIndex == words.count {
            return true
        }

        let boundaryText = text[words[wordIndex].range.upperBound..<words[nextWordIndex].range.lowerBound]
        return boundaryText.contains { isCommandSentenceBoundary($0) || $0.isNewline }
    }

    private func replacementRange(
        for match: CommandMatch,
        words: [WordToken],
        text: String
    ) -> Range<String.Index> {
        let commandStart = words[match.firstWordIndex].range.lowerBound
        let commandEnd = words[words.index(before: match.nextWordIndex)].range.upperBound
        let start = replacementStart(before: commandStart, in: text)
        let end = replacementEnd(
            after: commandEnd,
            in: text,
            consumesTrailingWhitespace: match.nextWordIndex == words.endIndex
        )

        return start..<end
    }

    private func replacementStart(before commandStart: String.Index, in text: String) -> String.Index {
        var current = commandStart
        while current > text.startIndex {
            let previous = text.index(before: current)
            guard isIgnorableLeadingCommandBoundary(text[previous]) else { break }
            current = previous
        }

        return current
    }

    private func replacementEnd(
        after commandEnd: String.Index,
        in text: String,
        consumesTrailingWhitespace: Bool
    ) -> String.Index {
        var current = commandEnd
        while current < text.endIndex {
            if text[current].isWhitespace, !consumesTrailingWhitespace {
                break
            }
            guard isIgnorableTrailingCommandBoundary(text[current]) else { break }
            current = text.index(after: current)
        }

        return current
    }

    private func isWhitespaceOnly(_ text: Substring) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }

    private func isIgnorableLeadingCommandBoundary(_ character: Character) -> Bool {
        character.isWhitespace || isCommandSentenceBoundary(character) || "([{\"'“‘".contains(character)
    }

    private func isIgnorableTrailingCommandBoundary(_ character: Character) -> Bool {
        character.isWhitespace || isCommandSentenceBoundary(character) || ")]}\"'”’".contains(character)
    }

    private func isCommandSentenceBoundary(_ character: Character) -> Bool {
        ".!?,:;".contains(character)
    }
}
