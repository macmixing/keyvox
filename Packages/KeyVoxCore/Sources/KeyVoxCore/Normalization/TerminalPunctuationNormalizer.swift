import Foundation
import KeyVoxLinguistics

public struct TerminalPunctuationNormalizer {
    private struct WordToken {
        let text: String
        let range: Range<String.Index>
        let lexicalClass: LexicalRole?
        let identity: LinguisticToken.Identity
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
        static let period = ["period"]
        static let fullStop = ["full", "stop"]
        static let comma = ["comma"]
    }

    private enum PauseSymbol {
        static let period: Character = "."
        static let comma: Character = ","
    }

    private static let terminalTimeRegex = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[1-9]|1[0-2]):[0-5][0-9]\s(?:AM|PM)\s*$"#
    )
    private static let terminalSentencePunctuationRegex = try? NSRegularExpression(
        pattern: #"[.!?…][\"'”’\)\]\}]*\s*$"#
    )
    private let casingPolicy = ContinuationCasingPolicy()

    public init() {}

    public func normalizeSpokenTerminalPunctuation(
        in text: String,
        dictionaryEntries: [DictionaryEntry] = []
    ) -> String {
        guard !text.isEmpty else { return text }

        let artifactNormalized = text.replacingOccurrences(
            of: ".dot.dot.",
            with: "...",
            options: .caseInsensitive
        )
        var normalized = normalizeSpokenEllipses(in: artifactNormalized)
        let words = wordTokens(in: normalized)
        guard !words.isEmpty else { return normalized }
        let commandMatches = terminalCommandMatches(in: words, text: normalized)
            .filter { isEligibleCommand(match: $0, words: words, text: normalized) }
        guard !commandMatches.isEmpty else { return normalized }

        var commaContinuationDistancesFromEnd: [Int] = []
        for commandMatch in commandMatches.reversed() {
            if commandMatch.symbols.last == PauseSymbol.comma, commandMatch.nextWordIndex < words.endIndex {
                commaContinuationDistancesFromEnd.append(
                    normalized.distance(
                        from: words[commandMatch.nextWordIndex].range.lowerBound,
                        to: normalized.endIndex
                    )
                )
            }
            let replacementRange = replacementRange(for: commandMatch, words: words, text: normalized)
            if let repair = pluralPossessiveRepair(
                before: commandMatch,
                words: words,
                text: normalized
            ) {
                normalized.replaceSubrange(
                    repair.start..<replacementRange.upperBound,
                    with: repair.pluralSuffix + commandMatch.symbols
                )
            } else {
                normalized.replaceSubrange(replacementRange, with: commandMatch.symbols)
            }
        }
        return lowercasingCommaContinuations(
            in: normalized,
            distancesFromEnd: commaContinuationDistancesFromEnd,
            dictionaryEntries: dictionaryEntries
        )
    }

    /// Lowercases a capital the transcriber gave the word after a spoken comma, unless the
    /// continuation casing policy says the capital belongs to the word.
    private func lowercasingCommaContinuations(
        in text: String,
        distancesFromEnd: [Int],
        dictionaryEntries: [DictionaryEntry]
    ) -> String {
        var result = text
        for distance in distancesFromEnd.sorted(by: >) {
            let start = result.index(result.endIndex, offsetBy: -distance)
            let token = String(result[start...].prefix { $0.isLetter || $0.isNumber || "_'’-".contains($0) })
            guard let firstCharacter = token.first, firstCharacter.isUppercase else { continue }

            let tokenRange = NSRange(start..<result.index(start, offsetBy: token.count), in: result)
            guard !casingPolicy.preservesCapital(
                of: token,
                at: tokenRange,
                in: result,
                dictionaryEntries: dictionaryEntries
            ) else {
                continue
            }

            result.replaceSubrange(start..<result.index(after: start), with: String(firstCharacter).lowercased())
        }
        return result
    }

    public func endsWithSpokenPauseCommand(_ text: String) -> Bool {
        let words = wordTokens(in: text)
        guard let lastMatch = terminalCommandMatches(in: words, text: text)
            .filter({ isEligibleCommand(match: $0, words: words, text: text) })
            .last,
              let lastSymbol = lastMatch.symbols.last else {
            return false
        }

        return lastMatch.nextWordIndex == words.endIndex && isPauseSymbol(lastSymbol)
    }

    private func normalizeSpokenEllipses(in text: String) -> String {
        let words = wordTokens(in: text)
        guard words.count >= 3 else { return text }

        var matches: [CommandMatch] = []
        var index = words.startIndex

        while index + 2 < words.endIndex {
            let nextIndex = index + 1
            let finalIndex = index + 2

            guard isSpokenDot(words[index]),
                  isSpokenDot(words[nextIndex]),
                  isSpokenDot(words[finalIndex]),
                  isPunctuationOnly(text[words[index].range.upperBound..<words[nextIndex].range.lowerBound]),
                  isPunctuationOnly(text[words[nextIndex].range.upperBound..<words[finalIndex].range.lowerBound]) else {
                index += 1
                continue
            }

            matches.append(CommandMatch(firstWordIndex: index, nextWordIndex: finalIndex + 1, symbols: "…"))
            index = finalIndex + 1
        }

        guard !matches.isEmpty else { return text }

        var normalized = text
        for match in matches.reversed() {
            let range = replacementRange(for: match, words: words, text: normalized)
            normalized.replaceSubrange(range, with: match.symbols)
        }
        return normalized
    }

    private func isSpokenDot(_ word: WordToken) -> Bool {
        word.text.caseInsensitiveCompare("dot") == .orderedSame
    }

    private func isPunctuationOnly(_ text: Substring) -> Bool {
        text.allSatisfy { $0.isWhitespace || $0.isPunctuation }
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
        let analysis = TextLinguistics.analyze(text, features: [.roles, .names, .wordBoundaries])
        return analysis.tokens.compactMap { token in
            guard let range = Range(token.range, in: text) else { return nil }
            return WordToken(
                text: String(text[range]),
                range: range,
                lexicalClass: token.role,
                identity: token.identity
            )
        }
    }

    /// Whether `word` reads as an ordinary noun once the spoken command after it is written as
    /// its mark, since the command's own words are not part of the sentence and can make the
    /// word before them read as a modifier.
    private func isOrdinaryNounInFinishedSentence(
        _ word: WordToken,
        before match: CommandMatch,
        words: [WordToken],
        text: String
    ) -> Bool {
        var finishedText = text
        finishedText.replaceSubrange(replacementRange(for: match, words: words, text: text), with: match.symbols)
        let location = NSRange(word.range, in: text).location
        let analysis = TextLinguistics.analyze(finishedText, features: [.roles, .names, .wordBoundaries])
        guard let token = analysis.tokens.first(where: { NSLocationInRange(location, $0.range) }) else {
            return false
        }
        return token.role == .noun && token.identity == .ordinaryWord
    }

    private func pluralPossessiveRepair(
        before match: CommandMatch,
        words: [WordToken],
        text: String
    ) -> (start: String.Index, pluralSuffix: String)? {
        let nounIndex = words.index(before: match.firstWordIndex)
        guard nounIndex >= words.startIndex + 2,
              words[nounIndex - 1].lexicalClass == .determiner,
              words[nounIndex - 2].lexicalClass == .preposition,
              isWhitespaceOnly(text[words[nounIndex].range.upperBound..<words[match.firstWordIndex].range.lowerBound]) else {
            return nil
        }

        let noun = words[nounIndex].text
        guard noun.count > 2,
              noun.last?.lowercased() == "s" else {
            return nil
        }

        let apostrophe = noun.index(noun.endIndex, offsetBy: -2)
        guard noun[apostrophe] == "'" || noun[apostrophe] == "’",
              isOrdinaryNounInFinishedSentence(words[nounIndex], before: match, words: words, text: text) else {
            return nil
        }

        if apostrophe > noun.startIndex {
            let finalStemCharacter = noun.index(before: apostrophe)
            if noun[finalStemCharacter].lowercased() == "y",
               finalStemCharacter > noun.startIndex {
                let precedingCharacter = noun[noun.index(before: finalStemCharacter)]
                if !"aeiou".contains(precedingCharacter.lowercased()) {
                    let start = text.index(
                        words[nounIndex].range.lowerBound,
                        offsetBy: noun.distance(from: noun.startIndex, to: finalStemCharacter)
                    )
                    return (start, noun[finalStemCharacter].isUppercase ? "IES" : "ies")
                }
            }

            let lowercaseStem = noun[..<apostrophe].lowercased()
            if lowercaseStem.hasSuffix("z") {
                let start = text.index(
                    words[nounIndex].range.lowerBound,
                    offsetBy: noun.distance(from: noun.startIndex, to: apostrophe)
                )
                let suffix = lowercaseStem.hasSuffix("zz") ? "es" : "zes"
                return (start, noun[finalStemCharacter].isUppercase ? suffix.uppercased() : suffix)
            }

            if ["s", "x", "ch", "sh"].contains(where: lowercaseStem.hasSuffix) {
                let start = text.index(
                    words[nounIndex].range.lowerBound,
                    offsetBy: noun.distance(from: noun.startIndex, to: apostrophe)
                )
                return (start, noun[finalStemCharacter].isUppercase ? "ES" : "es")
            }
        }

        let start = text.index(
            words[nounIndex].range.lowerBound,
            offsetBy: noun.distance(from: noun.startIndex, to: apostrophe)
        )
        return (start, "s")
    }

    private func terminalCommandMatches(in words: [WordToken], text: String) -> [CommandMatch] {
        var matches: [CommandMatch] = []
        var startIndex = words.startIndex

        while startIndex < words.endIndex {
            var currentIndex = startIndex
            var symbols = ""
            var lastSpokenSymbol = ""

            while currentIndex < words.count {
                guard let command = commandSymbol(startingAt: currentIndex, in: words, text: text) else {
                    break
                }

                lastSpokenSymbol = command.symbol
                currentIndex = command.nextIndex
                guard let commandSymbol = command.symbol.first, let lastSymbol = symbols.last else {
                    symbols += command.symbol
                    continue
                }

                // A period or comma spoken after a question mark or exclamation adds nothing,
                // and a question mark or exclamation spoken after one replaces it.
                if isPauseSymbol(commandSymbol), !isPauseSymbol(lastSymbol) {
                    continue
                }
                if isPauseSymbol(lastSymbol) {
                    symbols.removeLast()
                }
                symbols += command.symbol
            }

            if !symbols.isEmpty,
               isTerminalBoundary(afterWordAt: currentIndex - 1, nextWordIndex: currentIndex, words: words, text: text)
                || continuesAfterPauseCommand(symbols: lastSpokenSymbol, nextWordIndex: currentIndex, words: words) {
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

        if matches(SpokenCommand.period, startingAt: index, in: words, text: text) {
            return (String(PauseSymbol.period), index + SpokenCommand.period.count)
        }

        if matches(SpokenCommand.fullStop, startingAt: index, in: words, text: text) {
            return (String(PauseSymbol.period), index + SpokenCommand.fullStop.count)
        }

        if matches(SpokenCommand.comma, startingAt: index, in: words, text: text) {
            return (String(PauseSymbol.comma), index + SpokenCommand.comma.count)
        }

        return nil
    }

    private func isPauseSymbol(_ symbol: Character) -> Bool {
        symbol == PauseSymbol.period || symbol == PauseSymbol.comma
    }

    private func continuesAfterPauseCommand(symbols: String, nextWordIndex: Int, words: [WordToken]) -> Bool {
        guard nextWordIndex < words.endIndex, let lastSymbol = symbols.last else { return false }

        if lastSymbol == PauseSymbol.comma {
            return true
        }

        guard lastSymbol == PauseSymbol.period else { return false }
        return startsSentence(words[nextWordIndex])
    }

    private func startsSentence(_ word: WordToken) -> Bool {
        if word.lexicalClass == .pronoun || word.lexicalClass == .determiner {
            return true
        }

        guard let firstCharacter = word.text.first else { return false }
        return firstCharacter.isUppercase && word.identity != .name
    }

    private func isEmphaticSpokenPeriod(match: CommandMatch, words: [WordToken], text: String) -> Bool {
        guard match.symbols.last == PauseSymbol.period,
              match.nextWordIndex == words.endIndex,
              match.firstWordIndex > words.startIndex else {
            return false
        }

        let previousWord = words[words.index(before: match.firstWordIndex)]
        let leadingBoundary = text[previousWord.range.upperBound..<words[match.firstWordIndex].range.lowerBound]
        return leadingBoundary.contains(PauseSymbol.comma)
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
        if isEmphaticSpokenPeriod(match: match, words: words, text: text) {
            return false
        }

        // A comma has nothing to separate before the first word, so a leading "comma" is the word.
        guard match.firstWordIndex > words.startIndex else { return match.symbols.last != PauseSymbol.comma }

        let previousIndex = words.index(before: match.firstWordIndex)
        let previousWord = words[previousIndex]
        let leadingBoundary = text[previousWord.range.upperBound..<words[match.firstWordIndex].range.lowerBound]
        if leadingBoundary.contains(where: isCommandSentenceBoundary) || leadingBoundary.contains(where: \.isNewline) {
            return true
        }

        let endsInPauseSymbol = match.symbols.last.map(isPauseSymbol) ?? false
        if previousWord.lexicalClass == .determiner, endsInPauseSymbol {
            return false
        }

        if endsInPauseSymbol, endsNounPhrase(match: match, previousIndex: previousIndex, words: words, text: text) {
            return false
        }

        if previousWord.lexicalClass == .determiner,
           !isEligibleDeterminerCommand(
               previousIndex: previousIndex,
               match: match,
               words: words,
               text: text
           ) {
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

        if previousWord.lexicalClass == .verb,
           !endsInPauseSymbol,
           !hasExplicitCommandBoundaryAfter(match: match, words: words, text: text) {
            return false
        }

        return true
    }

    /// Whether a spoken period or comma is the noun ending a phrase opened by a determiner, as in
    /// "the trial period" or "a serial comma", rather than a command after that phrase.
    private func endsNounPhrase(match: CommandMatch, previousIndex: Int, words: [WordToken], text: String) -> Bool {
        guard opensNounPhrase(endingAt: previousIndex, words: words, text: text) else { return false }

        if match.symbols.last == PauseSymbol.period {
            return !hasExplicitCommandBoundaryAfter(match: match, words: words, text: text)
        }

        let previousWord = words[previousIndex]
        if previousWord.text.first?.isUppercase == true {
            return true
        }

        guard previousWord.lexicalClass == .adjective, match.nextWordIndex < words.endIndex else { return false }
        switch words[match.nextWordIndex].lexicalClass {
        case .preposition, .conjunction, .verb:
            return true
        default:
            return false
        }
    }

    /// Whether the descriptive words ending at `index` follow a determiner within one phrase.
    private func opensNounPhrase(endingAt index: Int, words: [WordToken], text: String) -> Bool {
        var current = index
        while current > words.startIndex {
            switch words[current].lexicalClass {
            case .adjective, .noun, .number, .ordinal:
                break
            default:
                return false
            }

            let previous = words.index(before: current)
            guard isWhitespaceOnly(text[words[previous].range.upperBound..<words[current].range.lowerBound]) else {
                return false
            }
            if words[previous].lexicalClass == .determiner {
                return true
            }
            current = previous
        }
        return false
    }

    private func isEligibleDeterminerCommand(
        previousIndex: Int,
        match: CommandMatch,
        words: [WordToken],
        text: String
    ) -> Bool {
        guard previousIndex > words.startIndex else {
            return false
        }

        let secondPreviousIndex = words.index(before: previousIndex)
        guard secondPreviousIndex > words.startIndex else {
            return false
        }

        let thirdPreviousIndex = words.index(before: secondPreviousIndex)
        if words[thirdPreviousIndex].lexicalClass == .pronoun,
           words[secondPreviousIndex].lexicalClass == .verb {
            return true
        }

        if words[secondPreviousIndex].lexicalClass == .preposition {
            if words[thirdPreviousIndex].lexicalClass == .noun {
                return true
            }

            if words[thirdPreviousIndex].lexicalClass == .adjective,
               !hasExplicitQuestionBoundaryAfter(match: match, words: words, text: text) {
                return true
            }
        }

        // Accept sentence-like clauses such as "happy to hear that exclamation point."
        guard thirdPreviousIndex > words.startIndex else { return false }
        let fourthPreviousIndex = words.index(before: thirdPreviousIndex)
        if words[thirdPreviousIndex].lexicalClass == .particle
            && words[secondPreviousIndex].lexicalClass == .verb
            && isNominalOrDescriptive(words[fourthPreviousIndex]) {
            return true
        }

        return words[thirdPreviousIndex].lexicalClass == .adverb
            && words[secondPreviousIndex].lexicalClass == .verb
            && (words[fourthPreviousIndex].lexicalClass == .verb
                || words[fourthPreviousIndex].lexicalClass == .pronoun)
    }

    private func isNominalOrDescriptive(_ word: WordToken) -> Bool {
        word.lexicalClass == .noun || word.lexicalClass == .adjective
    }

    private func hasExplicitCommandBoundaryAfter(
        match: CommandMatch,
        words: [WordToken],
        text: String
    ) -> Bool {
        let commandEnd = words[words.index(before: match.nextWordIndex)].range.upperBound
        let followingText: Substring
        if match.nextWordIndex < words.endIndex {
            followingText = text[commandEnd..<words[match.nextWordIndex].range.lowerBound]
        } else {
            followingText = text[commandEnd..<text.endIndex]
        }

        return followingText.contains(where: isCommandSentenceBoundary)
    }

    private func hasExplicitQuestionBoundaryAfter(
        match: CommandMatch,
        words: [WordToken],
        text: String
    ) -> Bool {
        let commandEnd = words[words.index(before: match.nextWordIndex)].range.upperBound
        let followingText: Substring
        if match.nextWordIndex < words.endIndex {
            followingText = text[commandEnd..<words[match.nextWordIndex].range.lowerBound]
        } else {
            followingText = text[commandEnd..<text.endIndex]
        }

        return followingText.contains("?")
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
