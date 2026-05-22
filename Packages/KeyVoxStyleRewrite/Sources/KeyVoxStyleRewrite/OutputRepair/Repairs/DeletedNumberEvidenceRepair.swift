import Foundation

struct DeletedNumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
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

            guard !runValues.isEmpty,
                  let previousRewrittenIndex = matches[runStart - 1],
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
            edits.append((separatorRange, " \(original[originalRunRange]) "))
            index = runEnd
        }

        guard !edits.isEmpty else { return rewritten }

        var repaired = rewritten
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }
}
