import Foundation

struct ChangedNumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 3, rewrittenTokens.count >= 2 else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let orderedMatches = matches
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }
        guard orderedMatches.count >= 2 else { return rewritten }

        var edits: [NumberEvidenceRepairSupport.Edit] = []
        for pairIndex in 0..<(orderedMatches.count - 1) {
            let left = orderedMatches[pairIndex]
            let right = orderedMatches[pairIndex + 1]
            guard right.originalIndex > left.originalIndex + 1,
                  right.rewrittenIndex > left.rewrittenIndex + 1 else {
                continue
            }

            let rewrittenRun = Array(rewrittenTokens[(left.rewrittenIndex + 1)..<right.rewrittenIndex])
            guard let rewrittenEvidence = NumberEvidence.components(in: rewrittenRun) else {
                continue
            }
            guard !NumberEvidenceRepairSupport.containsCurrencySymbol(in: rewrittenRun, text: rewritten) else {
                continue
            }

            let originalRun = Array(originalTokens[(left.originalIndex + 1)..<right.originalIndex])
            guard let originalEvidenceRun = NumberEvidenceRunAnalysis.originalEvidenceRun(
                in: originalRun,
                matching: rewrittenEvidence,
                sourceText: original,
                rewrittenRun: rewrittenRun,
                rewrittenText: rewritten
            ) else {
                continue
            }

            let isEquivalent = NumberEvidence.isEquivalent(
                originalEvidenceRun.evidence,
                rewrittenEvidence,
                leftRun: originalEvidenceRun.tokens,
                rightRun: rewrittenRun,
                leftText: original,
                rightText: rewritten
            )
            let preservesEquivalentSurface = isEquivalent && NumberEvidenceRunAnalysis.shouldPreserveOriginalSurface(
                tokens: originalEvidenceRun.tokens,
                fullRun: originalRun,
                in: original
            )
            guard !isEquivalent || preservesEquivalentSurface else {
                continue
            }

            let replacementRange = rewrittenTokens[left.rewrittenIndex].range.upperBound
                ..< rewrittenTokens[right.rewrittenIndex].range.lowerBound
            let replacementText: String
            if preservesEquivalentSurface {
                let sourceRange = NumberEvidenceRunAnalysis.preservedSurfaceRange(
                    leftAnchor: originalTokens[left.originalIndex],
                    tokens: originalEvidenceRun.tokens,
                    fullRun: originalRun,
                    rightAnchor: originalTokens[right.originalIndex]
                )
                replacementText = String(original[sourceRange])
            } else {
                let originalRunRange = originalEvidenceRun.tokens[0].range.lowerBound
                    ..< originalEvidenceRun.tokens[originalEvidenceRun.tokens.count - 1].range.upperBound
                replacementText = NumberEvidence.canonicalReplacementText(
                    evidence: originalEvidenceRun.evidence,
                    tokens: originalEvidenceRun.tokens,
                    sourceText: original,
                    sourceRange: originalRunRange
                )
            }
            NumberEvidenceRepairSupport.log(
                "keptChangedEvidence originalRun=\(originalEvidenceRun.tokens.map(\.text)) rewrittenRun=\(rewrittenRun.map(\.text)) "
                    + "replacement=\(NumberEvidenceRepairSupport.debugText(replacementText))"
            )
            edits.append((
                replacementRange,
                preservesEquivalentSurface ? replacementText : NumberEvidenceRepairSupport.spacedReplacement(replacementText)
            ))
        }

        if let trailingEdit = trailingChangedNumberEvidenceEdit(
            original: original,
            rewritten: rewritten,
            originalTokens: originalTokens,
            rewrittenTokens: rewrittenTokens,
            orderedMatches: orderedMatches
        ) {
            edits.append(trailingEdit)
        }

        return NumberEvidenceRepairSupport.applying(edits, to: rewritten)
    }

    private func trailingChangedNumberEvidenceEdit(
        original: String,
        rewritten: String,
        originalTokens: [RepairWordToken],
        rewrittenTokens: [RepairWordToken],
        orderedMatches: [(originalIndex: Int, rewrittenIndex: Int)]
    ) -> NumberEvidenceRepairSupport.Edit? {
        guard let last = orderedMatches.last,
              last.originalIndex < originalTokens.count - 1,
              last.rewrittenIndex < rewrittenTokens.count - 1 else {
            return nil
        }

        let originalRun = Array(originalTokens[(last.originalIndex + 1)..<originalTokens.count])
        let rewrittenRun = Array(rewrittenTokens[(last.rewrittenIndex + 1)..<rewrittenTokens.count])
        guard !NumberEvidenceRepairSupport.containsCurrencySymbol(in: rewrittenRun, text: rewritten),
              let originalEvidenceRun = NumberEvidenceRunAnalysis.singleNumberEvidenceRun(in: originalRun, sourceText: original),
              let rewrittenEvidenceRun = NumberEvidenceRunAnalysis.singleNumberEvidenceRun(in: rewrittenRun, sourceText: rewritten),
              !NumberEvidence.isEquivalent(
                originalEvidenceRun.evidence,
                rewrittenEvidenceRun.evidence,
                leftRun: originalEvidenceRun.tokens,
                rightRun: rewrittenEvidenceRun.tokens,
                leftText: original,
                rightText: rewritten
              ) else {
            return nil
        }

        let replacementRange = rewrittenTokens[last.rewrittenIndex].range.upperBound..<rewritten.endIndex
        let sourceRange = originalTokens[last.originalIndex].range.upperBound..<original.endIndex
        let evidenceSourceRange = originalEvidenceRun.tokens[0].range.lowerBound
            ..< originalEvidenceRun.tokens[originalEvidenceRun.tokens.count - 1].range.upperBound
        let evidenceReplacement = NumberEvidence.canonicalReplacementText(
            evidence: originalEvidenceRun.evidence,
            tokens: originalEvidenceRun.tokens,
            sourceText: original,
            sourceRange: evidenceSourceRange
        )
        let replacementText = String(original[sourceRange.lowerBound..<evidenceSourceRange.lowerBound])
            + evidenceReplacement
            + String(original[evidenceSourceRange.upperBound..<sourceRange.upperBound])

        NumberEvidenceRepairSupport.log(
            "keptTrailingChangedEvidence originalRun=\(originalEvidenceRun.tokens.map(\.text)) "
                + "rewrittenRun=\(rewrittenEvidenceRun.tokens.map(\.text)) replacement=\(NumberEvidenceRepairSupport.debugText(replacementText))"
        )
        return (replacementRange, replacementText)
    }
}
