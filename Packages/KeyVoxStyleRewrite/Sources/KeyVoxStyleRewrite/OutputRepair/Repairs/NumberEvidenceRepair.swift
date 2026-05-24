import Foundation

struct NumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let changedNumberRepaired = repairChangedNumberEvidence(original: original, rewritten: rewritten)
        let deletedNumberRepaired = repairDeletedNumberEvidence(original: original, rewritten: changedNumberRepaired)
        return NumberSeparatorEvidenceRepair().repair(original: original, rewritten: deletedNumberRepaired)
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

            let rewrittenRun = Array(rewrittenTokens[(left.rewrittenIndex + 1)..<right.rewrittenIndex])
            guard let rewrittenEvidence = NumberEvidence.components(in: rewrittenRun) else {
                continue
            }

            let originalRun = Array(originalTokens[(left.originalIndex + 1)..<right.originalIndex])
            guard let originalEvidenceRun = originalEvidenceRun(
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
            let preservesEquivalentSurface = isEquivalent && shouldPreserveOriginalSurface(
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
                let sourceRange = preservedSurfaceRange(
                    leftAnchor: originalTokens[left.originalIndex],
                    tokens: originalEvidenceRun.tokens,
                    fullRun: originalRun,
                    rightAnchor: originalTokens[right.originalIndex]
                )
                replacementText = String(original[sourceRange])
            } else {
                let originalRunRange = originalEvidenceRun.tokens[0].range.lowerBound..<originalEvidenceRun.tokens[originalEvidenceRun.tokens.count - 1].range.upperBound
                replacementText = NumberEvidence.canonicalReplacementText(
                    evidence: originalEvidenceRun.evidence,
                    tokens: originalEvidenceRun.tokens,
                    sourceText: original,
                    sourceRange: originalRunRange
                )
            }
            log(
                "keptChangedEvidence originalRun=\(originalEvidenceRun.tokens.map(\.text)) rewrittenRun=\(rewrittenRun.map(\.text)) replacement=\(debugText(replacementText))"
            )
            edits.append((
                replacementRange,
                preservesEquivalentSurface ? replacementText : spacedReplacement(replacementText)
            ))
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
        var edits: [(Range<String.Index>, String)] = []
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
                replacement = spacedReplacement(String(original[originalRunRange]))
            } else if canRestoreOriginalGap(originalGap: String(original[originalGapRange]), rewrittenSeparator: separator) {
                replacement = String(original[originalGapRange])
            } else {
                index = runEnd
                continue
            }

            log(
                "keptDeletedEvidence run=\(originalTokens[runStart..<runEnd].map(\.text)) replacement=\(debugText(replacement))"
            )
            edits.append((separatorRange, replacement))
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

    private func originalEvidenceRun(
        in tokens: [RepairWordToken],
        matching rewrittenEvidence: [NumberEvidence.Component],
        sourceText: String,
        rewrittenRun: [RepairWordToken],
        rewrittenText: String
    ) -> (tokens: [RepairWordToken], evidence: [NumberEvidence.Component])? {
        let candidates = contiguousNumberRuns(in: tokens, sourceText: sourceText)
        for candidate in candidates {
            guard let evidence = NumberEvidence.components(in: candidate),
                  NumberEvidence.isEquivalent(
                    evidence,
                    rewrittenEvidence,
                    leftRun: candidate,
                    rightRun: rewrittenRun,
                    leftText: sourceText,
                    rightText: rewrittenText
                  ) else {
                continue
            }
            return (candidate, evidence)
        }

        guard let evidence = NumberEvidence.components(in: tokens) else {
            return nil
        }
        return (tokens, evidence)
    }

    private func contiguousNumberRuns(in tokens: [RepairWordToken], sourceText: String) -> [[RepairWordToken]] {
        var runs: [[RepairWordToken]] = []
        var index = 0

        while index < tokens.count {
            guard RepairNumberParsing.numericValue(for: tokens[index]) != nil else {
                index += 1
                continue
            }

            var endIndex = index + 1
            while endIndex < tokens.count,
                  RepairNumberParsing.numericValue(for: tokens[endIndex]) != nil,
                  RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: sourceText) {
                endIndex += 1
            }

            runs.append(Array(tokens[index..<endIndex]))
            index = endIndex
        }

        return runs
    }

    private func shouldPreserveOriginalSurface(tokens: [RepairWordToken], fullRun: [RepairWordToken], in text: String) -> Bool {
        if fullRun.count > tokens.count,
           fullRun.allSatisfy({ RepairNumberParsing.numericValue(for: $0) != nil }) {
            return true
        }

        return tokens.count == 1 && tokens.contains { token in
            isPunctuationTerminatedNumberCue(token: token, in: text)
        }
    }

    private func preservedSurfaceRange(
        leftAnchor: RepairWordToken,
        tokens: [RepairWordToken],
        fullRun: [RepairWordToken],
        rightAnchor: RepairWordToken
    ) -> Range<String.Index> {
        let start = leftAnchor.range.upperBound
        if fullRun.count > tokens.count,
           let nextRunToken = fullRun.first(where: { $0.range.lowerBound >= tokens[tokens.count - 1].range.upperBound }) {
            return start..<nextRunToken.range.lowerBound
        }
        return start..<rightAnchor.range.lowerBound
    }

    private func isPunctuationTerminatedNumberCue(token: RepairWordToken, in text: String) -> Bool {
        guard !isOrderedListMarker(token: token, in: text),
              token.range.upperBound < text.endIndex else {
            return false
        }

        let next = text[token.range.upperBound]
        return next == "." || next == ","
    }

    private func isOrderedListMarker(token: RepairWordToken, in text: String) -> Bool {
        guard isStartOfLine(token.range.lowerBound, in: text),
              token.range.upperBound < text.endIndex,
              text[token.range.upperBound] == "." else {
            return false
        }

        let afterPeriod = text.index(after: token.range.upperBound)
        return afterPeriod == text.endIndex || text[afterPeriod].isWhitespace
    }

    private func isStartOfLine(_ index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else { return true }
        return text[text.index(before: index)].isNewline
    }

    private func canRestoreOriginalGap(originalGap: String, rewrittenSeparator: String) -> Bool {
        guard RepairTokenization.wordTokens(in: rewrittenSeparator).isEmpty,
              originalGap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return false
        }

        return originalGap.firstNonWhitespace == rewrittenSeparator.firstNonWhitespace
    }

    private func log(_ message: String) {
        #if DEBUG
        NSLog("[NumberEvidenceRepair] %@", message)
        #endif
    }

    private func debugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

private extension String {
    var firstNonWhitespace: Character? {
        first { !$0.isWhitespace }
    }
}
