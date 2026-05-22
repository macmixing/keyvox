import Foundation

struct PunctuationRepair {
    func repair(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
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
            rewrittenTokens: RepairTokenization.wordTokens(in: commaRemoved),
            original: original,
            rewritten: commaRemoved
        )
        return repairPercentSentenceSplit(sentenceCommaRepaired)
    }

    private func repairPercentSentenceSplit(_ text: String) -> String {
        RepairMatching.replacingMatches(
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

    private func removeCommaSeparatorsIntroducedByDeletion(
        originalTokens: [RepairWordToken],
        rewrittenTokens: [RepairWordToken],
        original: String,
        rewritten: String
    ) -> String {
        guard originalTokens.count > 1, rewrittenTokens.count > 1 else {
            return rewritten
        }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
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
            guard originalGap.contains(","), !RepairTokenization.wordTokens(in: originalGap).isEmpty else {
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

    private func restoreSentenceOpeningCommasRemovedWithDeletedTokens(
        originalTokens: [RepairWordToken],
        rewrittenTokens: [RepairWordToken],
        original: String,
        rewritten: String
    ) -> String {
        guard originalTokens.count > 1, rewrittenTokens.count > 1 else {
            return rewritten
        }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
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
                  !RepairTokenization.wordTokens(in: String(original[originalGapRange])).isEmpty else {
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

    private func startsWithComma(_ text: String) -> Bool {
        text.drop(while: \.isWhitespace).first == ","
    }

    private func isSentenceOpeningToken(_ token: RepairWordToken, in text: String) -> Bool {
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

    private func isCommaWhitespaceSeparator(_ text: String) -> Bool {
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
