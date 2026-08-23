import Foundation

struct UnsupportedCurrencyEvidenceRepair {
    private struct AlignedRun {
        let originalTokens: [RepairWordToken]
        let rewrittenTokens: [RepairWordToken]
        let sourceRange: Range<String.Index>
        let replacementRange: Range<String.Index>
    }

    func repair(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard !originalTokens.isEmpty, !rewrittenTokens.isEmpty else { return rewritten }

        let orderedMatches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }
        guard !orderedMatches.isEmpty else { return rewritten }

        let runs = alignedRuns(
            original: original,
            rewritten: rewritten,
            originalTokens: originalTokens,
            rewrittenTokens: rewrittenTokens,
            orderedMatches: orderedMatches
        )
        var edits: [NumberEvidenceRepairSupport.Edit] = []
        for run in runs {
            guard isUnsupportedMagnitudeRun(run.originalTokens),
                  NumberEvidenceRunAnalysis.containsNumberEvidence(
                      in: run.rewrittenTokens,
                      sourceText: rewritten
                  ),
                  containsCurrencyEvidence(in: run.originalTokens, text: original) == false,
                  NumberEvidenceRepairSupport.containsCurrencySymbol(
                      in: run.rewrittenTokens,
                      text: rewritten
                  ) else {
                continue
            }

            let replacementText = String(original[run.sourceRange])
            NumberEvidenceRepairSupport.log(
                "removedUnsupportedCurrency originalRun=\(run.originalTokens.map(\.text)) "
                    + "rewrittenRun=\(run.rewrittenTokens.map(\.text)) replacement=\(NumberEvidenceRepairSupport.debugText(replacementText))"
            )
            edits.append((run.replacementRange, replacementText))
        }

        return NumberEvidenceRepairSupport.applying(edits, to: rewritten)
    }

    private func alignedRuns(
        original: String,
        rewritten: String,
        originalTokens: [RepairWordToken],
        rewrittenTokens: [RepairWordToken],
        orderedMatches: [(originalIndex: Int, rewrittenIndex: Int)]
    ) -> [AlignedRun] {
        var runs: [AlignedRun] = []

        if let first = orderedMatches.first,
           first.originalIndex > originalTokens.startIndex,
           first.rewrittenIndex > rewrittenTokens.startIndex {
            runs.append(AlignedRun(
                originalTokens: Array(originalTokens[..<first.originalIndex]),
                rewrittenTokens: Array(rewrittenTokens[..<first.rewrittenIndex]),
                sourceRange: original.startIndex..<originalTokens[first.originalIndex].range.lowerBound,
                replacementRange: rewritten.startIndex..<rewrittenTokens[first.rewrittenIndex].range.lowerBound
            ))
        }

        if orderedMatches.count >= 2 {
            for pairIndex in 0..<(orderedMatches.count - 1) {
                let left = orderedMatches[pairIndex]
                let right = orderedMatches[pairIndex + 1]
                guard right.originalIndex > left.originalIndex + 1,
                      right.rewrittenIndex > left.rewrittenIndex + 1 else {
                    continue
                }

                runs.append(AlignedRun(
                    originalTokens: Array(originalTokens[(left.originalIndex + 1)..<right.originalIndex]),
                    rewrittenTokens: Array(rewrittenTokens[(left.rewrittenIndex + 1)..<right.rewrittenIndex]),
                    sourceRange: originalTokens[left.originalIndex].range.upperBound
                        ..< originalTokens[right.originalIndex].range.lowerBound,
                    replacementRange: rewrittenTokens[left.rewrittenIndex].range.upperBound
                        ..< rewrittenTokens[right.rewrittenIndex].range.lowerBound
                ))
            }
        }

        if let last = orderedMatches.last,
           last.originalIndex < originalTokens.index(before: originalTokens.endIndex),
           last.rewrittenIndex < rewrittenTokens.index(before: rewrittenTokens.endIndex) {
            runs.append(AlignedRun(
                originalTokens: Array(originalTokens[(last.originalIndex + 1)...]),
                rewrittenTokens: Array(rewrittenTokens[(last.rewrittenIndex + 1)...]),
                sourceRange: originalTokens[last.originalIndex].range.upperBound..<original.endIndex,
                replacementRange: rewrittenTokens[last.rewrittenIndex].range.upperBound..<rewritten.endIndex
            ))
        }

        return runs
    }

    private func isUnsupportedMagnitudeRun(_ tokens: [RepairWordToken]) -> Bool {
        guard tokens.count == 1, let token = tokens.first else { return false }
        return RepairNumberParsing.numericValue(for: token) == nil
            && RepairNumberParsing.canStartSpellOutIntegerParsing(token.text)
            && RepairNumberParsing.parsedSpellOutNumberPhraseWithImpliedUnit(token.text) != nil
    }

    private func containsCurrencyEvidence(in tokens: [RepairWordToken], text: String) -> Bool {
        NumberEvidenceRepairSupport.containsCurrencySymbol(in: tokens, text: text)
            || tokens.contains { CurrencyUnits.unit(for: $0.normalized) != nil }
    }
}
