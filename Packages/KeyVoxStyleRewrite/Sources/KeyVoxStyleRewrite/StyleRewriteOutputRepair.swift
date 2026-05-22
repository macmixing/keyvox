import Foundation

enum StyleRewriteOutputRepair {
    static func repairDeletedSeparatorPunctuation(original: String, rewritten: String) -> String {
        let originalTokens = wordTokens(in: original)
        let rewrittenTokens = wordTokens(in: rewritten)
        guard !originalTokens.isEmpty, !rewrittenTokens.isEmpty else {
            return rewritten
        }

        let commaRemoved = removeCommaSeparatorsIntroducedByDeletion(
            originalTokens: originalTokens,
            rewrittenTokens: rewrittenTokens,
            original: original,
            rewritten: rewritten
        )
        let sentenceCommaRepaired = restoreSentenceOpeningCommasRemovedWithDeletedTokens(
            originalTokens: originalTokens,
            rewrittenTokens: wordTokens(in: commaRemoved),
            original: original,
            rewritten: commaRemoved
        )
        let percentRepaired = repairPercentSentenceSplit(sentenceCommaRepaired)
        return repairAPStyleOrdinaryNumbers(original: original, rewritten: percentRepaired)
    }

    private struct WordToken: Equatable {
        let text: String
        let normalized: String
        let range: Range<String.Index>
    }

    private static let apStyleNumeralLowerBound = 10
    private static let spellOutNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        return formatter
    }()

    private static func wordTokens(in text: String) -> [WordToken] {
        var tokens: [WordToken] = []
        var tokenStart: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            if isWordCharacter(text[index]) {
                if tokenStart == nil {
                    tokenStart = index
                }
            } else if let start = tokenStart {
                appendToken(in: text, range: start..<index, to: &tokens)
                tokenStart = nil
            }

            index = text.index(after: index)
        }

        if let start = tokenStart {
            appendToken(in: text, range: start..<text.endIndex, to: &tokens)
        }

        return tokens
    }

    private static func repairPercentSentenceSplit(_ text: String) -> String {
        replacingMatches(
            in: text,
            pattern: #"(\d+)%\.\s+(?=[a-z])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 2 else { return nil }
            let percentRange = match.range(at: 1)
            guard percentRange.location != NSNotFound else { return nil }
            return "\(nsText.substring(with: percentRange))% "
        }
    }

    private static func repairAPStyleOrdinaryNumbers(original: String, rewritten: String) -> String {
        let lowDigitRepaired = repairLowOrdinaryDigits(original: original, rewritten: rewritten)
        return repairSpellOutNumberRuns(lowDigitRepaired)
    }

    private static func repairLowOrdinaryDigits(original: String, rewritten: String) -> String {
        let normalizedOriginal = original.lowercased()
        return replacingMatches(
            in: rewritten,
            pattern: #"(?<![\w$])([0-9])(?![\w])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 2 else { return nil }
            let digitRange = match.range(at: 1)
            guard digitRange.location != NSNotFound else { return nil }
            let digit = nsText.substring(with: digitRange)
            guard let value = Int(digit),
                  value < apStyleNumeralLowerBound,
                  let word = spellOutNumberFormatter.string(from: NSNumber(value: value)),
                  containsWord(word, in: normalizedOriginal),
                  !isProtectedLowDigit(match: match, in: nsText as String) else {
                return nil
            }
            return word
        }
    }

    private static func repairSpellOutNumberRuns(_ text: String) -> String {
        let tokens = wordTokens(in: text)
        guard !tokens.isEmpty else { return text }

        var edits: [(Range<String.Index>, String)] = []
        var index = 0
        while index < tokens.count {
            if let adjacentEndIndex = adjacentSingleNumberRunEnd(startingAt: index, tokens: tokens, in: text),
               !canParseWholeRun(startingAt: index, endingAt: adjacentEndIndex, tokens: tokens, in: text) {
                index = adjacentEndIndex
            } else if let replacement = spellOutNumberRunReplacement(startingAt: index, tokens: tokens, in: text) {
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

    private static func spellOutNumberRunReplacement(
        startingAt index: Int,
        tokens: [WordToken],
        in text: String
    ) -> (range: Range<String.Index>, text: String, endIndex: Int)? {
        let maximumEndIndex = contiguousCandidateEnd(startingAt: index, tokens: tokens, in: text)
        guard maximumEndIndex > index else { return nil }

        for endIndex in stride(from: maximumEndIndex, through: index + 1, by: -1) {
            let runRange = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
            let runText = String(text[runRange])
            guard let value = parsedSpellOutInteger(runText),
                  value >= apStyleNumeralLowerBound,
                  !isProtectedNumberRun(range: runRange, in: text) else {
                continue
            }
            return (runRange, String(value), endIndex)
        }

        return nil
    }

    private static func contiguousCandidateEnd(startingAt index: Int, tokens: [WordToken], in text: String) -> Int {
        var endIndex = index + 1
        while endIndex < tokens.count,
              isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text) {
            endIndex += 1
        }
        return endIndex
    }

    private static func adjacentSingleNumberRunEnd(startingAt index: Int, tokens: [WordToken], in text: String) -> Int? {
        guard parsedSpellOutInteger(tokens[index].text) != nil else { return nil }

        var endIndex = index + 1
        while endIndex < tokens.count,
              isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: text),
              parsedSpellOutInteger(tokens[endIndex].text) != nil {
            endIndex += 1
        }

        return endIndex > index + 1 ? endIndex : nil
    }

    private static func canParseWholeRun(startingAt index: Int, endingAt endIndex: Int, tokens: [WordToken], in text: String) -> Bool {
        let runRange = tokens[index].range.lowerBound..<tokens[endIndex - 1].range.upperBound
        return parsedSpellOutInteger(String(text[runRange])) != nil
    }

    private static func isProtectedLowDigit(match: NSTextCheckingResult, in text: String) -> Bool {
        guard let range = Range(match.range(at: 1), in: text) else { return true }
        if range.lowerBound > text.startIndex {
            let previous = text[text.index(before: range.lowerBound)]
            if previous == "$" || previous == ":" || previous == "." || previous == "/" || previous == "-" {
                return true
            }
        }
        if range.upperBound < text.endIndex {
            let next = text[range.upperBound]
            if next == ":" || next == "%" || next == "." || next == "/" || next == "-" {
                return true
            }
        }
        return false
    }

    private static func isProtectedNumberRun(range: Range<String.Index>, in text: String) -> Bool {
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

    private static func isNumberRunSeparator(between left: WordToken, and right: WordToken, in text: String) -> Bool {
        let separator = text[left.range.upperBound..<right.range.lowerBound]
        return separator.allSatisfy { $0.isWhitespace || $0 == "-" }
    }

    private static func parsedSpellOutInteger(_ text: String) -> Int? {
        let candidates = [
            text,
            text.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression),
        ]

        for candidate in candidates {
            guard let number = spellOutNumberFormatter.number(from: candidate),
                  let value = integerValue(from: number),
                  spellOutMatches(candidate, value: value) else {
                continue
            }
            return value
        }

        return nil
    }

    private static func integerValue(from number: NSNumber) -> Int? {
        let doubleValue = number.doubleValue
        guard doubleValue.isFinite,
              doubleValue.rounded() == doubleValue,
              doubleValue >= Double(Int.min),
              doubleValue <= Double(Int.max) else {
            return nil
        }
        return Int(doubleValue)
    }

    private static func spellOutMatches(_ text: String, value: Int) -> Bool {
        guard let spellOut = spellOutNumberFormatter.string(from: NSNumber(value: value)) else {
            return false
        }

        return normalizedSpellOut(text) == normalizedSpellOut(spellOut)
    }

    private static func normalizedSpellOut(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func containsWord(_ word: String, in normalizedText: String) -> Bool {
        let pattern = #"(?<![A-Za-z0-9])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![A-Za-z0-9])"#
        return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?
            .firstMatch(
                in: normalizedText,
                options: [],
                range: NSRange(normalizedText.startIndex..<normalizedText.endIndex, in: normalizedText)
            ) != nil
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options,
        replacement: (NSTextCheckingResult, NSString) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )
        guard !matches.isEmpty else { return text }

        var repaired = text
        for match in matches.reversed() {
            guard let range = Range(match.range, in: repaired),
                  let replacementText = replacement(match, nsText) else {
                continue
            }
            repaired.replaceSubrange(range, with: replacementText)
        }
        return repaired
    }

    private static func appendToken(
        in text: String,
        range: Range<String.Index>,
        to tokens: inout [WordToken]
    ) {
        let tokenText = String(text[range])
        let normalized = tokenText
            .lowercased()
            .filter { character in
                character.isLetter || character.isNumber
            }
        guard !normalized.isEmpty else { return }
        tokens.append(WordToken(text: tokenText, normalized: normalized, range: range))
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter
            || character.isNumber
            // Accept ASCII apostrophe plus right/left single quotation marks.
            || character == "'"
            || character == "’"
            || character == "‘"
    }

    private static func matchOriginalTokens(
        _ originalTokens: [WordToken],
        to rewrittenTokens: [WordToken]
    ) -> [Int: Int] {
        let originalCount = originalTokens.count
        let rewrittenCount = rewrittenTokens.count
        var lengths = Array(
            repeating: Array(repeating: 0, count: rewrittenCount + 1),
            count: originalCount + 1
        )

        if originalCount > 0, rewrittenCount > 0 {
            for originalIndex in stride(from: originalCount - 1, through: 0, by: -1) {
                for rewrittenIndex in stride(from: rewrittenCount - 1, through: 0, by: -1) {
                    if originalTokens[originalIndex].normalized == rewrittenTokens[rewrittenIndex].normalized {
                        lengths[originalIndex][rewrittenIndex] = lengths[originalIndex + 1][rewrittenIndex + 1] + 1
                    } else {
                        lengths[originalIndex][rewrittenIndex] = max(
                            lengths[originalIndex + 1][rewrittenIndex],
                            lengths[originalIndex][rewrittenIndex + 1]
                        )
                    }
                }
            }
        }

        var matches: [Int: Int] = [:]
        var originalIndex = 0
        var rewrittenIndex = 0
        while originalIndex < originalCount, rewrittenIndex < rewrittenCount {
            if originalTokens[originalIndex].normalized == rewrittenTokens[rewrittenIndex].normalized {
                matches[originalIndex] = rewrittenIndex
                originalIndex += 1
                rewrittenIndex += 1
            } else if lengths[originalIndex + 1][rewrittenIndex] >= lengths[originalIndex][rewrittenIndex + 1] {
                originalIndex += 1
            } else {
                rewrittenIndex += 1
            }
        }

        return matches
    }

    private static func removeCommaSeparatorsIntroducedByDeletion(
        originalTokens: [WordToken],
        rewrittenTokens: [WordToken],
        original: String,
        rewritten: String
    ) -> String {
        guard originalTokens.count > 1, rewrittenTokens.count > 1 else {
            return rewritten
        }

        let matches = matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let originalIndexByRewrittenIndex = Dictionary(
            uniqueKeysWithValues: matches.map { ($0.value, $0.key) }
        )
        var edits: [Range<String.Index>] = []

        for rewrittenIndex in rewrittenTokens.indices.dropLast() {
            let nextRewrittenIndex = rewrittenIndex + 1
            guard rewrittenIndex > rewrittenTokens.startIndex,
                  let originalIndex = originalIndexByRewrittenIndex[rewrittenIndex],
                  let nextOriginalIndex = originalIndexByRewrittenIndex[nextRewrittenIndex],
                  nextOriginalIndex > originalIndex + 1 else {
                continue
            }

            let separatorRange = rewrittenTokens[rewrittenIndex].range.upperBound
                ..< rewrittenTokens[nextRewrittenIndex].range.lowerBound
            let separator = String(rewritten[separatorRange])
            guard isCommaWhitespaceSeparator(separator) else {
                continue
            }

            let originalGapRange = originalTokens[originalIndex].range.upperBound
                ..< originalTokens[nextOriginalIndex].range.lowerBound
            let originalGap = String(original[originalGapRange])
            guard originalGap.contains(","), !wordTokens(in: originalGap).isEmpty else {
                continue
            }

            edits.append(separatorRange)
        }

        guard !edits.isEmpty else {
            return rewritten
        }

        var repaired = rewritten
        for range in edits.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            repaired.replaceSubrange(range, with: " ")
        }
        return repaired
    }

    private static func restoreSentenceOpeningCommasRemovedWithDeletedTokens(
        originalTokens: [WordToken],
        rewrittenTokens: [WordToken],
        original: String,
        rewritten: String
    ) -> String {
        guard originalTokens.count > 1, rewrittenTokens.count > 1 else {
            return rewritten
        }

        let matches = matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let originalIndexByRewrittenIndex = Dictionary(
            uniqueKeysWithValues: matches.map { ($0.value, $0.key) }
        )
        var edits: [Range<String.Index>] = []

        for rewrittenIndex in rewrittenTokens.indices.dropLast() {
            let nextRewrittenIndex = rewrittenIndex + 1
            guard let originalIndex = originalIndexByRewrittenIndex[rewrittenIndex],
                  let nextOriginalIndex = originalIndexByRewrittenIndex[nextRewrittenIndex],
                  nextOriginalIndex > originalIndex + 1,
                  isSentenceOpeningToken(originalTokens[originalIndex], in: original) else {
                continue
            }

            let separatorRange = rewrittenTokens[rewrittenIndex].range.upperBound
                ..< rewrittenTokens[nextRewrittenIndex].range.lowerBound
            guard String(rewritten[separatorRange]).allSatisfy(\.isWhitespace) else {
                continue
            }

            let originalGapRange = originalTokens[originalIndex].range.upperBound
                ..< originalTokens[nextOriginalIndex].range.lowerBound
            guard startsWithComma(String(original[originalGapRange])),
                  !wordTokens(in: String(original[originalGapRange])).isEmpty else {
                continue
            }

            edits.append(separatorRange)
        }

        guard !edits.isEmpty else {
            return rewritten
        }

        var repaired = rewritten
        for range in edits.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            repaired.replaceSubrange(range, with: ", ")
        }
        return repaired
    }

    private static func startsWithComma(_ text: String) -> Bool {
        text.drop(while: \.isWhitespace).first == ","
    }

    private static func isSentenceOpeningToken(_ token: WordToken, in text: String) -> Bool {
        var index = token.range.lowerBound
        while index > text.startIndex {
            let previous = text.index(before: index)
            if text[previous].isWhitespace {
                index = previous
                continue
            }
            return text[previous] == "." || text[previous] == "?" || text[previous] == "!"
        }
        return true
    }

    private static func isCommaWhitespaceSeparator(_ text: String) -> Bool {
        var hasComma = false
        for character in text {
            if character == "," {
                hasComma = true
            } else if !character.isWhitespace {
                return false
            }
        }
        return hasComma
    }
}
