import Foundation

struct DeletedNumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 3, rewrittenTokens.count >= 2 else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        var edits: [NumberEvidenceRepairSupport.Edit] = []
        var index = 1

        while index < originalTokens.count - 1 {
            guard matches[index] == nil,
                  RepairNumberParsing.numericValue(for: originalTokens[index]) != nil else {
                index += 1
                continue
            }

            let runStart = index
            var runEnd = index + 1
            while runEnd < originalTokens.count - 1,
                  matches[runEnd] == nil,
                  RepairNumberParsing.numericValue(for: originalTokens[runEnd]) != nil,
                  RepairNumberParsing.isNumberRunSeparator(between: originalTokens[runEnd - 1], and: originalTokens[runEnd], in: original) {
                runEnd += 1
            }

            guard let previousRewrittenIndex = matches[runStart - 1],
                  let nextRewrittenIndex = matches[runEnd],
                  nextRewrittenIndex == previousRewrittenIndex + 1 else {
                index = runEnd
                continue
            }

            let separatorRange = rewrittenTokens[previousRewrittenIndex].range.upperBound
                ..< rewrittenTokens[nextRewrittenIndex].range.lowerBound
            let originalRunRange = originalTokens[runStart].range.lowerBound..<originalTokens[runEnd - 1].range.upperBound
            let originalGapRange = originalTokens[runStart - 1].range.upperBound..<originalTokens[runEnd].range.lowerBound
            let separator = String(rewritten[separatorRange])
            let replacement: String
            if separator.allSatisfy(\.isWhitespace) {
                replacement = NumberEvidenceRepairSupport.spacedReplacement(String(original[originalRunRange]))
            } else if NumberEvidenceRepairSupport.canRestoreOriginalGap(
                originalGap: String(original[originalGapRange]),
                rewrittenSeparator: separator
            ) {
                replacement = String(original[originalGapRange])
            } else {
                index = runEnd
                continue
            }

            NumberEvidenceRepairSupport.log(
                "keptDeletedEvidence run=\(originalTokens[runStart..<runEnd].map(\.text)) "
                    + "replacement=\(NumberEvidenceRepairSupport.debugText(replacement))"
            )
            edits.append((separatorRange, replacement))
            index = runEnd
        }

        return NumberEvidenceRepairSupport.applying(edits, to: rewritten)
    }
}
