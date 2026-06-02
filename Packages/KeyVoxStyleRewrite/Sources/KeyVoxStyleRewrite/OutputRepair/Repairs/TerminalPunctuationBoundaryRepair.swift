import Foundation

struct TerminalPunctuationBoundaryRepair {
    func repair(original: String, rewritten: String) -> String {
        guard !original.isEmpty else {
            return rewritten
        }

        let originalTokens = RepairTokenization.wordTokens(in: original)
        var repaired = rewritten
        var rewrittenTokens = RepairTokenization.wordTokens(in: repaired)

        guard !originalTokens.isEmpty, !rewrittenTokens.isEmpty else {
            return rewritten
        }

        repaired = repairPunctuationBoundaries(
            originalTokens: originalTokens,
            original: original,
            rewrittenTokens: rewrittenTokens,
            rewritten: repaired
        )

        rewrittenTokens = RepairTokenization.wordTokens(in: repaired)
        return repairTerminalPunctuation(
            originalTokens: originalTokens,
            original: original,
            rewrittenTokens: rewrittenTokens,
            rewritten: repaired
        )
    }

    private func repairPunctuationBoundaries(
        originalTokens: [RepairWordToken],
        original: String,
        rewrittenTokens: [RepairWordToken],
        rewritten: String
    ) -> String {
        guard originalTokens.count > 1, rewrittenTokens.count > 1 else {
            return rewritten
        }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let orderedMatches = matches
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }

        var edits: [(Range<String.Index>, String)] = []
        for pairIndex in 0..<(orderedMatches.count - 1) {
            let left = orderedMatches[pairIndex]
            let right = orderedMatches[pairIndex + 1]
            guard let sourcePunctuation = sourcePunctuationCluster(
                from: originalTokens[left.originalIndex],
                to: originalTokens[right.originalIndex],
                in: original
            ) else {
                continue
            }

            let rewrittenSeparatorRange = rewrittenTokens[left.rewrittenIndex].range.upperBound
                ..< rewrittenTokens[right.rewrittenIndex].range.lowerBound
            let rewrittenSeparator = String(rewritten[rewrittenSeparatorRange])
            guard canReplaceSeparator(rewrittenSeparator) else {
                continue
            }

            edits.append((rewrittenSeparatorRange, sourcePunctuation + trailingWhitespace(in: rewrittenSeparator)))
        }

        guard !edits.isEmpty else { return rewritten }

        var repaired = rewritten
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func repairTerminalPunctuation(
        originalTokens: [RepairWordToken],
        original: String,
        rewrittenTokens: [RepairWordToken],
        rewritten: String
    ) -> String {
        guard let rewrittenLast = rewrittenTokens.last,
              let rewrittenLastIndex = rewrittenTokens.indices.last else {
            return rewritten
        }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        guard let originalLastIndex = matches.first(where: { $0.value == rewrittenLastIndex })?.key,
              let sourcePunctuation = sourceTailPunctuationCluster(after: originalTokens[originalLastIndex], in: original) else {
            return rewritten
        }

        let rewrittenTailRange = rewrittenLast.range.upperBound..<rewritten.endIndex
        let rewrittenTail = String(rewritten[rewrittenTailRange])
        guard canReplaceSeparator(rewrittenTail) else {
            return rewritten
        }

        var repaired = rewritten
        repaired.replaceSubrange(rewrittenTailRange, with: sourcePunctuation)
        return repaired
    }

    private func sourcePunctuationCluster(
        from leftToken: RepairWordToken,
        to rightToken: RepairWordToken,
        in text: String
    ) -> String? {
        let boundary = text[leftToken.range.upperBound..<rightToken.range.lowerBound]
        return punctuationCluster(in: boundary)
    }

    private func sourceTailPunctuationCluster(after token: RepairWordToken, in text: String) -> String? {
        let tail = text[token.range.upperBound..<text.endIndex]
        return punctuationCluster(in: tail)
    }

    private func punctuationCluster(in text: Substring) -> String? {
        let punctuation = text.filter { $0 == "!" || $0 == "?" }
        guard punctuation.contains("!") else {
            return nil
        }

        return String(punctuation)
    }

    private func canReplaceSeparator(_ separator: String) -> Bool {
        return RepairTokenization.wordTokens(in: separator).isEmpty
    }

    private func trailingWhitespace(in text: String) -> String {
        let suffix = text.reversed().prefix { $0.isWhitespace }.reversed()
        return String(suffix)
    }
}
