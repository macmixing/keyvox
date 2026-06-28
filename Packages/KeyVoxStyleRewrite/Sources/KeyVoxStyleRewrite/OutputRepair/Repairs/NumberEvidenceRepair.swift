import Foundation

struct NumberEvidenceRepair {
    func repair(original: String, rewritten: String) -> String {
        let fusedDecimalRepaired = repairFusedDecimalEvidence(original: original, rewritten: rewritten)
        let truncatedDecimalRepaired = repairTruncatedDecimalEvidence(original: original, rewritten: fusedDecimalRepaired)
        let decimalWidthRepaired = repairDecimalFractionWidthEvidence(original: original, rewritten: truncatedDecimalRepaired)
        let changedNumberRepaired = repairChangedNumberEvidence(original: original, rewritten: decimalWidthRepaired)
        let insertedNumberRepaired = repairInsertedNumberEvidence(original: original, rewritten: changedNumberRepaired)
        let deletedNumberRepaired = repairDeletedNumberEvidence(original: original, rewritten: insertedNumberRepaired)
        return NumberSeparatorEvidenceRepair().repair(original: original, rewritten: deletedNumberRepaired)
    }

    private func repairFusedDecimalEvidence(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 4, !rewrittenTokens.isEmpty else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let orderedMatches = matches
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }

        var edits: [(Range<String.Index>, String)] = []
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

        guard !edits.isEmpty else { return rewritten }

        var repaired = rewritten
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func repairDecimalFractionWidthEvidence(original: String, rewritten: String) -> String {
        let sourceDecimals = sourceDecimalTexts(in: original).filter { decimal in
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
        var edits: [(Range<String.Index>, String)] = []

        if matches.isEmpty,
           rewrittenTokens.count == 1,
           let decimalRun = decimalRunStarting(at: 0, in: originalTokens, sourceText: original),
           decimalRun.endIndex == originalTokens.count,
           let majorValue = RepairNumberParsing.numericValue(for: rewrittenTokens[0]),
           let evidence = NumberEvidence.components(in: originalTokens),
           let decimalText = NumberEvidence.decimalReplacementText(evidence: evidence, tokens: originalTokens),
           decimalText.hasPrefix("\(majorValue).") {
            edits.append((rewrittenTokens[0].range, decimalText))
        }

        for originalIndex in originalTokens.indices {
            guard let rewrittenIndex = matches[originalIndex],
                  let decimalRun = decimalRunStarting(at: originalIndex, in: originalTokens, sourceText: original),
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

            if let nextMatchedOriginalIndex = nextMatchedOriginalIndex(after: originalIndex, matches: matches),
               nextMatchedOriginalIndex < decimalRun.endIndex {
                continue
            }

            if let nextMatchedRewrittenIndex = nextMatchedRewrittenIndex(after: rewrittenIndex, matches: matches),
               nextMatchedRewrittenIndex != rewrittenIndex + 1 {
                continue
            }

            log(
                "repairedTruncatedDecimalEvidence run=\(originalTokens[originalIndex..<decimalRun.endIndex].map(\.text)) replacement=\(debugText(decimalText))"
            )
            edits.append((rewrittenTokens[rewrittenIndex].range, decimalText))
        }

        guard !edits.isEmpty else { return rewritten }

        var repaired = rewritten
        for edit in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            repaired.replaceSubrange(edit.0, with: edit.1)
        }
        return repaired
    }

    private func repairChangedNumberEvidence(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 3, rewrittenTokens.count >= 2 else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let orderedMatches = matches
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }
        guard orderedMatches.count >= 2 else { return rewritten }

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
            guard !containsCurrencySymbol(in: rewrittenRun, text: rewritten) else {
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

    private func repairInsertedNumberEvidence(original: String, rewritten: String) -> String {
        let originalTokens = RepairTokenization.wordTokens(in: original)
        let rewrittenTokens = RepairTokenization.wordTokens(in: rewritten)
        guard originalTokens.count >= 3, rewrittenTokens.count >= 3 else { return rewritten }

        let matches = RepairMatching.matchOriginalTokens(originalTokens, to: rewrittenTokens)
        let orderedMatches = matches
            .map { (originalIndex: $0.key, rewrittenIndex: $0.value) }
            .sorted { $0.originalIndex < $1.originalIndex }

        var edits: [(Range<String.Index>, String)] = []
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
                guard containsNumberEvidence(in: originalRun, sourceText: original) == false,
                      containsNumberEvidence(in: rewrittenRun, sourceText: rewritten) else {
                    continue
                }

                let replacementRange = rewrittenTokens[left.rewrittenIndex].range.upperBound
                    ..< rewrittenTokens[right.rewrittenIndex].range.lowerBound
                if let replacementText = currencyReplacement(
                    originalRun: originalRun,
                    rewrittenRun: rewrittenRun,
                    replacementRange: replacementRange,
                    rewritten: rewritten
                ) {
                    edits.append((replacementRange, replacementText))
                    continue
                }
                guard !containsCurrencySymbol(in: rewrittenRun, text: rewritten) else {
                    continue
                }
                let sourceRange = originalTokens[left.originalIndex].range.upperBound
                    ..< originalTokens[right.originalIndex].range.lowerBound
                let replacementText = String(original[sourceRange])
                log(
                    "keptOriginalGapForInsertedEvidence originalRun=\(originalRun.map(\.text)) rewrittenRun=\(rewrittenRun.map(\.text)) replacement=\(debugText(replacementText))"
                )
                edits.append((replacementRange, replacementText))
            }
        }

        if let last = orderedMatches.last,
           last.originalIndex < originalTokens.count - 1,
           last.rewrittenIndex < rewrittenTokens.count - 1 {
            let originalRun = Array(originalTokens[(last.originalIndex + 1)..<originalTokens.count])
            let rewrittenRun = Array(rewrittenTokens[(last.rewrittenIndex + 1)..<rewrittenTokens.count])
            if containsNumberEvidence(in: originalRun, sourceText: original) == false,
               containsNumberEvidence(in: rewrittenRun, sourceText: rewritten) {
                let replacementRange = rewrittenTokens[last.rewrittenIndex].range.upperBound..<rewritten.endIndex
                if let replacementText = currencyReplacement(
                    originalRun: originalRun,
                    rewrittenRun: rewrittenRun,
                    replacementRange: replacementRange,
                    rewritten: rewritten
                ) {
                    edits.append((replacementRange, replacementText))
                }
            }
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

    private func appendFusedDecimalEdit(
        originalRun: [RepairWordToken],
        rewrittenRun: [RepairWordToken],
        edits: inout [(Range<String.Index>, String)]
    ) {
        guard let replacement = fusedDecimalReplacement(
            originalRun: originalRun,
            rewrittenRun: rewrittenRun
        ) else {
            return
        }

        log(
            "repairedFusedDecimalEvidence originalRun=\(originalRun.map(\.text)) rewrittenRun=\(rewrittenRun.map(\.text)) replacement=\(debugText(replacement))"
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

    private func sourceDecimalTexts(in text: String) -> [(text: String, major: String, minor: String)] {
        let tokens = RepairTokenization.wordTokens(in: text)
        guard tokens.count >= 3 else { return [] }

        var decimals: [(text: String, major: String, minor: String)] = []
        for index in tokens.indices {
            guard let decimalRun = decimalRunStarting(at: index, in: tokens, sourceText: text),
                  let evidence = NumberEvidence.components(in: Array(tokens[decimalRun])),
                  let decimalText = NumberEvidence.decimalReplacementText(
                    evidence: evidence,
                    tokens: Array(tokens[decimalRun])
                  ),
                  let separatorIndex = decimalText.firstIndex(of: ".") else {
                continue
            }

            decimals.append((
                text: decimalText,
                major: String(decimalText[..<separatorIndex]),
                minor: String(decimalText[decimalText.index(after: separatorIndex)...])
            ))
        }

        return decimals
    }

    private func decimalRunStarting(
        at index: Int,
        in tokens: [RepairWordToken],
        sourceText: String
    ) -> Range<Int>? {
        guard index + 2 < tokens.count,
              RepairNumberParsing.numericValue(for: tokens[index]) != nil,
              RepairNumberParsing.isSpellOutDecimalSeparator(tokens[index + 1]),
              RepairNumberParsing.isNumberRunSeparator(between: tokens[index], and: tokens[index + 1], in: sourceText) else {
            return nil
        }

        var endIndex = index + 2
        while endIndex < tokens.count,
              RepairNumberParsing.numericValue(for: tokens[endIndex]) != nil,
              RepairNumberParsing.isNumberRunSeparator(between: tokens[endIndex - 1], and: tokens[endIndex], in: sourceText) {
            endIndex += 1
        }

        return index..<endIndex
    }

    private func nextMatchedOriginalIndex(after index: Int, matches: [Int: Int]) -> Int? {
        matches.keys.filter { $0 > index }.min()
    }

    private func nextMatchedRewrittenIndex(after index: Int, matches: [Int: Int]) -> Int? {
        matches.values.filter { $0 > index }.min()
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

    private func containsNumberEvidence(in tokens: [RepairWordToken], sourceText: String) -> Bool {
        NumberEvidence.components(in: tokens) != nil
            || contiguousNumberRuns(in: tokens, sourceText: sourceText).isEmpty == false
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

    private func containsCurrencySymbol(in tokens: [RepairWordToken], text: String) -> Bool {
        tokens.contains { token in
            let prefix = text[..<token.range.lowerBound].suffix(4)
            return CurrencyUnits.symbols.contains { symbol in
                prefix.hasSuffix(symbol)
            }
        }
    }

    private func currencyReplacement(
        originalRun: [RepairWordToken],
        rewrittenRun: [RepairWordToken],
        replacementRange: Range<String.Index>,
        rewritten: String
    ) -> String? {
        guard let unit = originalRun.compactMap({ CurrencyUnits.unit(for: $0.normalized) }).first(where: { $0.scale == .major }),
              rewrittenRun.count == 1,
              rewrittenRun[0].text.allSatisfy(\.isNumber),
              containsCurrencySymbol(in: rewrittenRun, text: rewritten) == false else {
            return nil
        }

        let originalText = String(rewritten[replacementRange])
        let leadingWhitespace = String(originalText.prefix(while: \.isWhitespace))
        let suffix = String(rewritten[rewrittenRun[0].range.upperBound..<replacementRange.upperBound])
        return "\(leadingWhitespace)\(unit.symbol)\(rewrittenRun[0].text)\(suffix)"
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
