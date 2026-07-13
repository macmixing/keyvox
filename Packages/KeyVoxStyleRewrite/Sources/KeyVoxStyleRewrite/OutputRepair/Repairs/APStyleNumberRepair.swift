import Foundation

struct APStyleNumberRepair {
    private final class TokenNumberCache {
        private var values: [String: Int] = [:]
        private var rejected: Set<String> = []

        func value(for token: RepairWordToken) -> Int? {
            let key = token.normalized
            if let value = values[key] {
                return value
            }
            guard !rejected.contains(key),
                  RepairNumberParsing.canStartSpellOutIntegerParsing(token.text),
                  let value = RepairNumberParsing.parsedSpellOutInteger(token.text) else {
                rejected.insert(key)
                return nil
            }
            values[key] = value
            return value
        }
    }

    private static let maximumNumberPhraseTokenCount = 16

    func repair(original: String, rewritten: String) -> String {
        let collapsedRunRepaired = repairCollapsedAdjacentNumberRuns(original: original, rewritten: rewritten)
        let lowDigitRepaired = repairLowOrdinaryDigits(original: original, rewritten: collapsedRunRepaired)
        return repairSpellOutNumberRuns(lowDigitRepaired)
    }

    private func repairCollapsedAdjacentNumberRuns(original: String, rewritten: String) -> String {
        let tokens = RepairTokenization.wordTokens(in: original)
        guard tokens.count >= 2 else { return rewritten }

        var repaired = rewritten
        var index = 0
        let tokenNumberCache = TokenNumberCache()
        while index < tokens.count {
            guard let adjacentEndIndex = adjacentSingleNumberRunEnd(
                startingAt: index,
                tokens: tokens,
                in: original,
                tokenNumberCache: tokenNumberCache
            ),
                  !canParseWholeRun(startingAt: index, endingAt: adjacentEndIndex, tokens: tokens, in: original),
                  let replacement = adjacentNumberRunReplacement(startingAt: index, endingAt: adjacentEndIndex, tokens: tokens) else {
                index += 1
                continue
            }

            let collapsedDigits = replacement.values.map(String.init).joined()
            repaired = RepairMatching.replacingMatches(
                in: repaired,
                pattern: #"(?<![\w])\#(NSRegularExpression.escapedPattern(for: collapsedDigits))-(?=[\p{L}])"#,
                options: []
            ) { _, _ in
                replacement.text + " "
            }
            index = adjacentEndIndex
        }

        return repaired
    }

    private func repairLowOrdinaryDigits(original: String, rewritten: String) -> String {
        let normalizedOriginal = original.lowercased()
        return RepairMatching.replacingMatches(
            in: rewritten,
            pattern: #"(?<![\w$])([0-9])(?![\w])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 2 else { return nil }
            let digitRange = match.range(at: 1)
            guard digitRange.location != NSNotFound else { return nil }
            let digit = nsText.substring(with: digitRange)
            let text = nsText as String
            guard let range = Range(digitRange, in: text) else { return nil }
            guard let value = Int(digit),
                  value < RepairNumberParsing.apStyleNumeralLowerBound,
                  let word = RepairNumberParsing.spellOutString(for: value),
                  RepairMatching.containsWord(word, in: normalizedOriginal),
                  !isOrderedListMarker(range: range, in: text),
                  !isProtectedLowDigit(match: match, in: text) else {
                return nil
            }
            return word
        }
    }

    private func repairSpellOutNumberRuns(_ text: String) -> String {
        let tokens = RepairTokenization.wordTokens(in: text)
        guard !tokens.isEmpty else { return text }

        var edits: [(Range<String.Index>, String)] = []
        var index = 0
        let tokenNumberCache = TokenNumberCache()
        while index < tokens.count {
            if let adjacentEndIndex = adjacentSingleNumberRunEnd(
                startingAt: index,
                tokens: tokens,
                in: text,
                tokenNumberCache: tokenNumberCache
            ),
               !canParseWholeRun(startingAt: index, endingAt: adjacentEndIndex, tokens: tokens, in: text) {
                index = adjacentEndIndex
            } else if let replacement = spellOutNumberRunReplacement(
                startingAt: index,
                tokens: tokens,
                in: text,
                tokenNumberCache: tokenNumberCache
            ) {
                edits.append((replacement.range, replacement.text))
                index = replacement.endIndex
            } else {
                index += 1
            }
        }

        guard !edits.isEmpty else { return text }

        var repaired = text
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func spellOutNumberRunReplacement(
        startingAt index: Int,
        tokens: [RepairWordToken],
        in text: String,
        tokenNumberCache: TokenNumberCache
    ) -> (range: Range<String.Index>, text: String, endIndex: Int)? {
        guard tokenNumberCache.value(for: tokens[index]) != nil else {
            return nil
        }

        let maximumEndIndex = contiguousCandidateEnd(startingAt: index, tokens: tokens, in: text)
        guard maximumEndIndex > index else { return nil }

        for endIndex in stride(from: maximumEndIndex, through: index + 1, by: -1) {
            let runRange = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
            let runText = String(text[runRange])
            let runTokens = Array(tokens[index..<endIndex])
            guard let value = RepairNumberParsing.parsedSpellOutNumberPhrase(runText)
                    ?? RepairNumberParsing.parsedSpellOutInteger(runText)
                    ?? RepairNumberParsing.parsedConnectorNumberRun(runTokens),
                  value >= RepairNumberParsing.apStyleNumeralLowerBound,
                  !isProtectedNumberRun(range: runRange, in: text) else {
                continue
            }
            return (runRange, String(value), endIndex)
        }

        return nil
    }

    private func adjacentNumberRunReplacement(
        startingAt index: Int,
        endingAt endIndex: Int,
        tokens: [RepairWordToken]
    ) -> (values: [Int], text: String)? {
        var values: [Int] = []
        var parts: [String] = []
        for token in tokens[index..<endIndex] {
            guard let value = RepairNumberParsing.parsedSpellOutInteger(token.text) else {
                return nil
            }
            values.append(value)
            if value >= RepairNumberParsing.apStyleNumeralLowerBound {
                parts.append(String(value))
            } else if let word = RepairNumberParsing.spellOutString(for: value) {
                parts.append(word)
            } else {
                return nil
            }
        }
        return (values, parts.joined(separator: " "))
    }

    private func contiguousCandidateEnd(startingAt index: Int, tokens: [RepairWordToken], in text: String) -> Int {
        var endIndex = index + 1
        let upperBound = min(tokens.count, index + Self.maximumNumberPhraseTokenCount)
        while endIndex < tokens.count,
              endIndex < upperBound,
              RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text) {
            endIndex += 1
        }
        return endIndex
    }

    private func adjacentSingleNumberRunEnd(
        startingAt index: Int,
        tokens: [RepairWordToken],
        in text: String,
        tokenNumberCache: TokenNumberCache
    ) -> Int? {
        guard tokenNumberCache.value(for: tokens[index]) != nil else { return nil }

        var endIndex = index + 1
        while endIndex < tokens.count,
              RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text),
              tokenNumberCache.value(for: tokens[endIndex]) != nil {
            endIndex += 1
        }

        return endIndex > index + 1 ? endIndex : nil
    }

    private func canParseWholeRun(startingAt index: Int, endingAt endIndex: Int, tokens: [RepairWordToken], in text: String) -> Bool {
        let runRange = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
        return RepairNumberParsing.parsedSpellOutInteger(String(text[runRange])) != nil
    }

    private func isProtectedLowDigit(match: NSTextCheckingResult, in text: String) -> Bool {
        guard let range = Range(match.range(at: 1), in: text) else { return true }
        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if previous == "$" || previous == ":" || previous == "/" || previous == "-" {
                return true
            }
            if previous == "." {
                return true
            }
        }
        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if next == ":",
               !isOrderedListIntroColon(at: range.upperBound, in: text) {
                return true
            }
            if next == "%" || next == "/" || next == "-" {
                return true
            }
            if next == ".",
               text.index(after: range.upperBound) < text.endIndex,
               text[text.index(after: range.upperBound)].isNumber {
                return true
            }
        }
        return false
    }

    private func isProtectedNumberRun(range: Range<String.Index>, in text: String) -> Bool {
        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if previous == "$" || previous == ":" || previous == "/" || previous == "-" {
                return true
            }
        }
        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if next == ":" || next == "%" || next == "/" || next == "-" {
                return true
            }
        }

        return false
    }

    private func isOrderedListMarker(range: Range<String.Index>, in text: String) -> Bool {
        guard isStartOfLine(range.lowerBound, in: text),
              range.upperBound < text.endIndex,
              text[range.upperBound] == "." else {
            return false
        }

        let afterPeriod = text.index(after: range.upperBound)
        return afterPeriod == text.endIndex || text[afterPeriod].isWhitespace
    }

    private func isOrderedListIntroColon(at colonIndex: String.Index, in text: String) -> Bool {
        var index = text.index(after: colonIndex)
        var sawNewline = false

        while index < text.endIndex, text[index].isWhitespace {
            if text[index].isNewline {
                sawNewline = true
            }
            index = text.index(after: index)
        }

        guard sawNewline else { return false }

        let markerStart = index
        while index < text.endIndex, text[index].isNumber {
            index = text.index(after: index)
        }

        guard markerStart < index,
              index < text.endIndex,
              text[index] == "." else {
            return false
        }

        let afterPeriod = text.index(after: index)
        return afterPeriod == text.endIndex || text[afterPeriod].isWhitespace
    }

    private func isStartOfLine(_ index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        return text[text.index(before: index)].isNewline
    }

}
