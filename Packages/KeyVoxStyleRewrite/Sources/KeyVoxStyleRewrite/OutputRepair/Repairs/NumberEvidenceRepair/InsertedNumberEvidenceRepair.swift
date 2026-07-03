import Foundation

struct InsertedNumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 3, rewrittenTokens.count >= 3 else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let orderedMatches = matches
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }

        var edits: [NumberEvidenceRepairSupport.Edit] = []
        if orderedMatches.count >= 2 {
            for pairIndex in 0..<(orderedMatches.count - 1) {
                let left = orderedMatches[pairIndex]
                let right = orderedMatches[pairIndex + 1]
                guard right.originalIndex > left.originalIndex + 1,
                      right.rewrittenIndex > left.rewrittenIndex + 1 else {
                    continue
                }

                let originalRun = Array(originalTokens[(left.originalIndex + 1)..<right.originalIndex])
                let rewrittenRun = Array(rewrittenTokens[(left.rewrittenIndex + 1)..<right.rewrittenIndex])
                guard NumberEvidenceRunAnalysis.containsNumberEvidence(in: originalRun, sourceText: original) == false,
                      NumberEvidenceRunAnalysis.containsNumberEvidence(in: rewrittenRun, sourceText: rewritten) else {
                    continue
                }

                let replacementRange = rewrittenTokens[left.rewrittenIndex].range.upperBound
                    ..< rewrittenTokens[right.rewrittenIndex].range.lowerBound
                if let replacementText = NumberEvidenceRepairSupport.currencyReplacement(
                    originalRun: originalRun,
                    rewrittenRun: rewrittenRun,
                    replacementRange: replacementRange,
                    rewritten: rewritten
                ) {
                    edits.append((replacementRange, replacementText))
                    continue
                }
                guard !NumberEvidenceRepairSupport.containsCurrencySymbol(in: rewrittenRun, text: rewritten) else {
                    continue
                }
                let sourceRange = originalTokens[left.originalIndex].range.upperBound
                    ..< originalTokens[right.originalIndex].range.lowerBound
                let replacementText = String(original[sourceRange])
                NumberEvidenceRepairSupport.log(
                    "keptOriginalGapForInsertedEvidence originalRun=\(originalRun.map(\.text)) "
                        + "rewrittenRun=\(rewrittenRun.map(\.text)) replacement=\(NumberEvidenceRepairSupport.debugText(replacementText))"
                )
                edits.append((replacementRange, replacementText))
            }
        }

        if let last = orderedMatches.last,
           last.originalIndex < originalTokens.count - 1,
           last.rewrittenIndex < rewrittenTokens.count - 1 {
            let originalRun = Array(originalTokens[(last.originalIndex + 1)..<originalTokens.count])
            let rewrittenRun = Array(rewrittenTokens[(last.rewrittenIndex + 1)..<rewrittenTokens.count])
            if NumberEvidenceRunAnalysis.containsNumberEvidence(in: originalRun, sourceText: original) == false,
               NumberEvidenceRunAnalysis.containsNumberEvidence(in: rewrittenRun, sourceText: rewritten) {
                let replacementRange = rewrittenTokens[last.rewrittenIndex].range.upperBound..<rewritten.endIndex
                if let replacementText = NumberEvidenceRepairSupport.currencyReplacement(
                    originalRun: originalRun,
                    rewrittenRun: rewrittenRun,
                    replacementRange: replacementRange,
                    rewritten: rewritten
                ) {
                    edits.append((replacementRange, replacementText))
                }
            }
        }

        return NumberEvidenceRepairSupport.applying(edits, to: rewritten)
    }
}
