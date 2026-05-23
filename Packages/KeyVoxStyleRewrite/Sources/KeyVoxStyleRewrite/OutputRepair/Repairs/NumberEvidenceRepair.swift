import Foundation

struct NumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let changedNumberRepaired = repairChangedNumberEvidence(original: original, rewritten: rewritten)
        return repairDeletedNumberEvidence(original: original, rewritten: changedNumberRepaired)
    }

    private func repairChangedNumberEvidence(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 3, rewrittenTokens.count >= 2 else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let orderedMatches = matches
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }

        var edits: [(Range<String.Index>, String)] = []
        for pairIndex in 0..<(orderedMatches.count - 1) {
            let left = orderedMatches[pairIndex]
            let right = orderedMatches[pairIndex + 1]
            guard right.originalIndex > left.originalIndex + 1,
                  right.rewrittenIndex > left.rewrittenIndex + 1 else {
                continue
            }

            let originalRun = Array(originalTokens[(left.originalIndex + 1)..<right.originalIndex])
            let rewrittenRun = Array(rewrittenTokens[(left.rewrittenIndex + 1)..<right.rewrittenIndex])
            guard let originalEvidence = NumberEvidence.components(in: originalRun),
                  let rewrittenEvidence = NumberEvidence.components(in: rewrittenRun),
                  !NumberEvidence.isEquivalent(
                    originalEvidence,
                    rewrittenEvidence,
                    leftRun: originalRun,
                    rightRun: rewrittenRun,
                    leftText: original,
                    rightText: rewritten
                  ) else {
                continue
            }

            let replacementRange = rewrittenTokens[left.rewrittenIndex].range.upperBound
                ..< rewrittenTokens[right.rewrittenIndex].range.lowerBound
            let originalRunRange = originalRun[0].range.lowerBound..<originalRun[originalRun.count - 1].range.upperBound
            let replacementText = NumberEvidence.canonicalReplacementText(
                evidence: originalEvidence,
                tokens: originalRun,
                sourceText: original,
                sourceRange: originalRunRange
            )
            edits.append((replacementRange, spacedReplacement(replacementText)))
        }

        guard !edits.isEmpty else { return rewritten }

        var repaired = rewritten
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func repairDeletedNumberEvidence(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 3, rewrittenTokens.count >= 2 else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let rewrittenNumberValues = Set(rewrittenTokens.compactMap { RepairNumberParsing.numericValue(for: $0) })
        var edits: [(Range<String.Index>, String)] = []
        var index = 1

        while index < originalTokens.count - 1 {
            guard matches[index] == nil,
                  let value = RepairNumberParsing.numericValue(for: originalTokens[index]),
                  !rewrittenNumberValues.contains(value) else {
                index += 1
                continue
            }

            let runStart = index
            var runEnd = index + 1
            var runValues = Set([value])
            while runEnd < originalTokens.count - 1,
                  matches[runEnd] == nil,
                  let runValue = RepairNumberParsing.numericValue(for: originalTokens[runEnd]),
                  !rewrittenNumberValues.contains(runValue) {
                runValues.insert(runValue)
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
            guard String(rewritten[separatorRange]).allSatisfy(\.isWhitespace) else {
                index = runEnd
                continue
            }

            let originalRunRange = originalTokens[runStart].range.lowerBound..<originalTokens[runEnd - 1].range.upperBound
            edits.append((separatorRange, spacedReplacement(String(original[originalRunRange]))))
            index = runEnd
        }

        guard !edits.isEmpty else { return rewritten }

        var repaired = rewritten
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func spacedReplacement(_ text: String) -> String {
        " \(text) "
    }
}
