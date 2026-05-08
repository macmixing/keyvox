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
        return restoreSentenceOpeningCommasRemovedWithDeletedTokens(
            originalTokens: originalTokens,
            rewrittenTokens: wordTokens(in: commaRemoved),
            original: original,
            rewritten: commaRemoved
        )
    }

    private struct WordToken: Equatable {
        let text: String
        let normalized: String
        let range: Range<String.Index>
    }

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
