import Foundation

struct DecimalNumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let fusedDecimalRepaired = repairFusedDecimalEvidence(original: original, rewritten: rewritten)
        let truncatedDecimalRepaired = repairTruncatedDecimalEvidence(original: original, rewritten: fusedDecimalRepaired)
        return repairDecimalFractionWidthEvidence(original: original, rewritten: truncatedDecimalRepaired)
    }

    private func repairFusedDecimalEvidence(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 4, !rewrittenTokens.isEmpty else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let orderedMatches = matches
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }

        var edits: [NumberEvidenceRepairSupport.Edit] = []
        if orderedMatches.isEmpty {
            appendFusedDecimalEdit(
                originalRun: originalTokens,
                rewrittenRun: rewrittenTokens,
                edits: &edits
            )
        } else {
            if let first = orderedMatches.first,
               first.originalIndex >= 4,
               first.rewrittenIndex == 1 {
                appendFusedDecimalEdit(
                    originalRun: Array(originalTokens[0..<first.originalIndex]),
                    rewrittenRun: Array(rewrittenTokens[0..<first.rewrittenIndex]),
                    edits: &edits
                )
            }

            if orderedMatches.count >= 2 {
                for pairIndex in 0..<(orderedMatches.count - 1) {
                    let left = orderedMatches[pairIndex]
                    let right = orderedMatches[pairIndex + 1]
                    guard right.originalIndex > left.originalIndex + 3,
                          right.rewrittenIndex == left.rewrittenIndex + 2 else {
                        continue
                    }

                    appendFusedDecimalEdit(
                        originalRun: Array(originalTokens[(left.originalIndex + 1)..<right.originalIndex]),
                        rewrittenRun: Array(rewrittenTokens[(left.rewrittenIndex + 1)..<right.rewrittenIndex]),
                        edits: &edits
                    )
                }
            }

            if let last = orderedMatches.last,
               originalTokens.count >= last.originalIndex + 5,
               rewrittenTokens.count == last.rewrittenIndex + 2 {
                appendFusedDecimalEdit(
                    originalRun: Array(originalTokens[(last.originalIndex + 1)..<originalTokens.count]),
                    rewrittenRun: Array(rewrittenTokens[(last.rewrittenIndex + 1)..<rewrittenTokens.count]),
                    edits: &edits
                )
            }
        }

        return NumberEvidenceRepairSupport.applying(edits, to: rewritten)
    }

    private func repairDecimalFractionWidthEvidence(original: String, rewritten: String) -> String {
        let sourceDecimals = NumberEvidenceRunAnalysis.sourceDecimalTexts(in: original).filter { decimal in
            decimal.minor.hasPrefix("0")
        }
        guard !sourceDecimals.isEmpty else { return rewritten }

        return RepairMatching.replacingMatches(
            in: rewritten,
            pattern: #"(?<![\w.])([0-9]+)\.([0-9]+)(?![\w.])"#,
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 3,
                  let minor = Int(nsText.substring(with: match.range(at: 2))) else {
                return nil
            }

            let major = nsText.substring(with: match.range(at: 1))
            guard let sourceDecimal = sourceDecimals.first(where: {
                $0.major == major && Int($0.minor) == minor
            }) else {
                return nil
            }

            return sourceDecimal.text
        }
    }

    private func repairTruncatedDecimalEvidence(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 3, !rewrittenTokens.isEmpty else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        var edits: [NumberEvidenceRepairSupport.Edit] = []

        if matches.isEmpty,
           rewrittenTokens.count == 1,
           let decimalRun = NumberEvidenceRunAnalysis.decimalRunStarting(at: 0, in: originalTokens, sourceText: original),
           decimalRun.endIndex == originalTokens.count,
           let majorValue = RepairNumberParsing.numericValue(for: rewrittenTokens[0]),
           let evidence = NumberEvidence.components(in: originalTokens),
           let decimalText = NumberEvidence.decimalReplacementText(evidence: evidence, tokens: originalTokens),
           decimalText.hasPrefix("\(majorValue).") {
            edits.append((rewrittenTokens[0].range, decimalText))
        }

        for originalIndex in originalTokens.indices {
            guard let rewrittenIndex = matches[originalIndex],
                  let decimalRun = NumberEvidenceRunAnalysis.decimalRunStarting(
                    at: originalIndex,
                    in: originalTokens,
                    sourceText: original
                  ),
                  decimalRun.endIndex > originalIndex + 2,
                  decimalRun[(originalIndex + 1)...].allSatisfy({ matches[$0] == nil }),
                  let majorValue = RepairNumberParsing.numericValue(for: rewrittenTokens[rewrittenIndex]),
                  let evidence = NumberEvidence.components(in: Array(originalTokens[originalIndex..<decimalRun.endIndex])),
                  let decimalText = NumberEvidence.decimalReplacementText(
                    evidence: evidence,
                    tokens: Array(originalTokens[originalIndex..<decimalRun.endIndex])
                  ),
                  decimalText.hasPrefix("\(majorValue).") else {
                continue
            }

            if let nextMatchedOriginalIndex = NumberEvidenceRunAnalysis.nextMatchedOriginalIndex(after: originalIndex, matches: matches),
               nextMatchedOriginalIndex < decimalRun.endIndex {
                continue
            }

            if let nextMatchedRewrittenIndex = NumberEvidenceRunAnalysis.nextMatchedRewrittenIndex(after: rewrittenIndex, matches: matches),
               nextMatchedRewrittenIndex != rewrittenIndex + 1 {
                continue
            }

            NumberEvidenceRepairSupport.log(
                "repairedTruncatedDecimalEvidence run=\(originalTokens[originalIndex..<decimalRun.endIndex].map(\.text)) "
                    + "replacement=\(NumberEvidenceRepairSupport.debugText(decimalText))"
            )
            edits.append((rewrittenTokens[rewrittenIndex].range, decimalText))
        }

        return NumberEvidenceRepairSupport.applying(edits, to: rewritten)
    }

    private func appendFusedDecimalEdit(
        originalRun: [RepairWordToken],
        rewrittenRun: [RepairWordToken],
        edits: inout [NumberEvidenceRepairSupport.Edit]
    ) {
        guard let replacement = fusedDecimalReplacement(
            originalRun: originalRun,
            rewrittenRun: rewrittenRun
        ) else {
            return
        }

        NumberEvidenceRepairSupport.log(
            "repairedFusedDecimalEvidence originalRun=\(originalRun.map(\.text)) rewrittenRun=\(rewrittenRun.map(\.text)) "
                + "replacement=\(NumberEvidenceRepairSupport.debugText(replacement))"
        )
        edits.append((rewrittenRun[0].range, replacement))
    }

    private func fusedDecimalReplacement(
        originalRun: [RepairWordToken],
        rewrittenRun: [RepairWordToken]
    ) -> String? {
        guard originalRun.count >= 4,
              rewrittenRun.count == 1,
              let prefixAndDigits = splitAlphaPrefixAndDigitSuffix(rewrittenRun[0].text),
              originalRun[0].normalized == prefixAndDigits.prefix.lowercased() else {
            return nil
        }

        let decimalTokens = Array(originalRun.dropFirst())
        guard let decimalEvidence = NumberEvidence.components(in: decimalTokens),
              let decimalText = NumberEvidence.decimalReplacementText(evidence: decimalEvidence, tokens: decimalTokens),
              decimalText.filter(\.isNumber) == prefixAndDigits.digits else {
            return nil
        }

        return "\(prefixAndDigits.prefix)-\(decimalText)"
    }

    private func splitAlphaPrefixAndDigitSuffix(_ text: String) -> (prefix: String, digits: String)? {
        let prefix = text.prefix(while: \.isLetter)
        let suffixStart = text.lastIndex(where: { !$0.isNumber }).map { text.index(after: $0) } ?? text.startIndex
        let digits = text[suffixStart...]
        guard !prefix.isEmpty,
              digits.count >= 2,
              prefix.count + digits.count == text.count else {
            return nil
        }

        return (String(prefix), String(digits))
    }
}
