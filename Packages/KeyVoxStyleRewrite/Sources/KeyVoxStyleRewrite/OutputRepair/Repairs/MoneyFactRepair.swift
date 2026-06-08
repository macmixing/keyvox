import Foundation

struct MoneyFactRepair {
    private struct SourceMoneySpan {
        let majorValue: Int
        let minorValue: Int?
        let symbol: String
    }

    private struct RewrittenMoneySpan {
        let majorValue: Int
        let minorValue: Int?
        let symbol: String
        let majorText: String
        let range: Range<String.Index>
    }

    func repair(original: String, rewritten: String) -> String {
        let sourceSpans = sourceMoneySpans(in: original)
        guard !sourceSpans.isEmpty else { return rewritten }

        let splitRepaired = repairSplitMoneyAmount(sourceSpans: sourceSpans, rewritten: rewritten)
        let multipleAmountDriftRepaired = repairMultipleMoneyAmountDrift(
            sourceSpans: sourceMoneySpansIncludingImpliedMajorUnits(
                in: original,
                explicitSpans: sourceSpans,
                expectedCount: rewrittenMoneySpans(in: splitRepaired).count
            ),
            rewritten: splitRepaired
        )
        let amountDriftRepaired = repairSingleMoneyAmountDrift(sourceSpans: sourceSpans, rewritten: multipleAmountDriftRepaired)
        return repairRedundantMinorUnit(sourceSpans: sourceSpans, rewritten: amountDriftRepaired)
    }

    private func repairSplitMoneyAmount(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        RepairMatching.replacingMatches(
            in: rewritten,
            pattern: "(\(CurrencyUnits.symbolPattern))\\s*(\\d+)\\s+and(?:\\s+[\\p{L}'’]+){0,2}\\s+(\(CurrencyUnits.symbolPattern))\\s*(\\d{1,2})(?!\\d|\\.\\d)",
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 5,
                  let major = Int(nsText.substring(with: match.range(at: 2))),
                  let minor = Int(nsText.substring(with: match.range(at: 4))),
                  minor < 100,
                  let sourceSpan = sourceSpans.first(where: { sourceSpan in
                    sourceSpan.majorValue == major && sourceSpan.minorValue != nil
                  }) else {
                return nil
            }

            let symbol = nsText.substring(with: match.range(at: 1))
            guard symbol == nsText.substring(with: match.range(at: 3)),
                  symbol == sourceSpan.symbol else {
                return nil
            }
            return formattedMoneyAmount(symbol: symbol, sourceSpan: sourceSpan, matchingMajorText: nsText.substring(with: match.range(at: 2)))
        }
    }

    private func repairSingleMoneyAmountDrift(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        guard sourceSpans.count == 1,
              rewrittenMoneySpans(in: rewritten).count == 1,
              let sourceSpan = sourceSpans.first else {
            return rewritten
        }

        return RepairMatching.replacingMatches(
            in: rewritten,
            pattern: "(\(CurrencyUnits.symbolPattern))\\s*(\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.(\\d{1,2}))?(?!\\d|\\.\\d)",
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 4 else { return nil }
            let symbol = nsText.substring(with: match.range(at: 1))
            guard symbol == sourceSpan.symbol else { return nil }
            guard let major = integerAmount(from: nsText.substring(with: match.range(at: 2))) else { return nil }

            let minorRange = match.range(at: 3)
            let minor = minorRange.location == NSNotFound
                ? nil
                : Int(nsText.substring(with: minorRange).padding(toLength: 2, withPad: "0", startingAt: 0))
            guard major != sourceSpan.majorValue || minor != sourceSpan.minorValue else {
                return nil
            }

            return formattedMoneyAmount(symbol: symbol, sourceSpan: sourceSpan, matchingMajorText: nsText.substring(with: match.range(at: 2)))
        }
    }

    private func repairMultipleMoneyAmountDrift(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        guard sourceSpans.count > 1 else { return rewritten }

        let rewrittenSpans = rewrittenMoneySpans(in: rewritten)
        guard rewrittenSpans.count == sourceSpans.count,
              zip(sourceSpans, rewrittenSpans).allSatisfy({ $0.symbol == $1.symbol }) else {
            return rewritten
        }

        var repaired = rewritten
        for (sourceSpan, rewrittenSpan) in zip(sourceSpans, rewrittenSpans).reversed() {
            guard sourceSpan.majorValue != rewrittenSpan.majorValue
                    || sourceSpan.minorValue != rewrittenSpan.minorValue else {
                continue
            }
            repaired.replaceSubrange(
                rewrittenSpan.range,
                with: formattedMoneyAmount(symbol: rewrittenSpan.symbol, sourceSpan: sourceSpan, matchingMajorText: rewrittenSpan.majorText)
            )
        }
        return repaired
    }

    private func repairRedundantMinorUnit(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        let sourceSpansWithMinor = sourceSpans.filter { $0.minorValue != nil }
        guard !sourceSpansWithMinor.isEmpty else { return rewritten }

        return RepairMatching.replacingMatches(
            in: rewritten,
            pattern: "(\(CurrencyUnits.symbolPattern))\\s*(\\d+)\\.(\\d{1,2})\\s+(\(CurrencyUnits.unitPattern(for: .minor)))(?![\\p{L}'’])",
            options: [.caseInsensitive]
        ) { match, nsText in
            guard match.numberOfRanges == 5,
                  let major = Int(nsText.substring(with: match.range(at: 2))),
                  let minor = Int(nsText.substring(with: match.range(at: 3)).padding(toLength: 2, withPad: "0", startingAt: 0)) else {
                return nil
            }

            let symbol = nsText.substring(with: match.range(at: 1))
            let minorUnit = CurrencyUnits.unit(for: nsText.substring(with: match.range(at: 4)))
            guard minorUnit?.symbol == symbol,
                  minorUnit?.scale == .minor,
                  let sourceSpan = sourceSpansWithMinor.first(where: {
                    $0.symbol == symbol
                        && $0.majorValue == major
                        && $0.minorValue == minor
                  }) else {
                return nil
            }

            return formattedMoneyAmount(symbol: symbol, sourceSpan: sourceSpan, matchingMajorText: nsText.substring(with: match.range(at: 2)))
        }
    }

    private func formattedMoneyAmount(
        symbol: String,
        sourceSpan: SourceMoneySpan,
        matchingMajorText: String
    ) -> String {
        let majorText = majorValueText(sourceSpan.majorValue, matching: matchingMajorText)
        if let minorValue = sourceSpan.minorValue {
            return "\(symbol)\(majorText).\(String(format: "%02d", minorValue))"
        }
        return "\(symbol)\(majorText)"
    }

    private func majorValueText(_ value: Int, matching rewrittenMajorText: String) -> String {
        guard rewrittenMajorText.contains(",") else {
            return "\(value)"
        }

        var digits = Array(String(value))
        var output = ""
        for character in rewrittenMajorText.reversed() {
            if character == "," {
                output.insert(character, at: output.startIndex)
            } else if let digit = digits.popLast() {
                output.insert(digit, at: output.startIndex)
            }
        }

        if !digits.isEmpty {
            output = String(digits) + output
        }
        return output
    }

    private func integerAmount(from text: String) -> Int? {
        Int(text.replacingOccurrences(of: ",", with: ""))
    }

    private func rewrittenMoneySpans(in text: String) -> [RewrittenMoneySpan] {
        let pattern = "(\(CurrencyUnits.symbolPattern))\\s*(\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.(\\d{1,2}))?(?!\\d|\\.\\d)"
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges == 4,
                  let fullRange = Range(match.range(at: 0), in: text),
                  let majorValue = integerAmount(from: nsText.substring(with: match.range(at: 2))) else {
                return nil
            }

            let minorRange = match.range(at: 3)
            let minorValue = minorRange.location == NSNotFound
                ? nil
                : Int(nsText.substring(with: minorRange).padding(toLength: 2, withPad: "0", startingAt: 0))
            return RewrittenMoneySpan(
                majorValue: majorValue,
                minorValue: minorValue,
                symbol: nsText.substring(with: match.range(at: 1)),
                majorText: nsText.substring(with: match.range(at: 2)),
                range: fullRange
            )
        }
    }

    private func sourceMoneySpans(in text: String) -> [SourceMoneySpan] {
        let tokens = RepairTokenization.taggedTokens(in: text)
        guard !tokens.isEmpty else { return [] }

        var spans: [SourceMoneySpan] = []
        var index = tokens.startIndex
        while index < tokens.endIndex {
            guard let majorRun = numericRunBeforeUnit(startingAt: index, in: tokens, sourceText: text),
                  majorRun.endIndex < tokens.endIndex,
                  let majorValue = NumberEvidence.parsedValue(in: Array(tokens[majorRun.range].map(\.token))),
                  let majorUnit = CurrencyUnits.unit(for: tokens[majorRun.endIndex].lemma),
                  majorUnit.scale == .major else {
                index += 1
                continue
            }

            var minorValue: Int?
            var nextIndex = majorRun.endIndex + 1
            if nextIndex < tokens.endIndex,
               tokens[nextIndex].tag == .conjunction,
               let minorStartIndex = minorStartIndex(afterConjunctionAt: nextIndex, in: tokens),
               let minorRun = numericRunBeforeUnit(startingAt: minorStartIndex, in: tokens, sourceText: text),
               minorRun.endIndex < tokens.endIndex,
               let parsedMinorValue = NumberEvidence.parsedValue(in: Array(tokens[minorRun.range].map(\.token))),
               parsedMinorValue < 100,
               let minorUnit = CurrencyUnits.unit(for: tokens[minorRun.endIndex].lemma),
               minorUnit.scale == .minor {
                minorValue = parsedMinorValue
                nextIndex = minorRun.endIndex + 1
            }

            spans.append(SourceMoneySpan(
                majorValue: majorValue,
                minorValue: minorValue,
                symbol: majorUnit.symbol
            ))
            index = nextIndex
        }

        return spans
    }

    private func sourceMoneySpansIncludingImpliedMajorUnits(
        in text: String,
        explicitSpans: [SourceMoneySpan],
        expectedCount: Int
    ) -> [SourceMoneySpan] {
        guard expectedCount > explicitSpans.count,
              let firstSymbol = explicitSpans.first?.symbol else {
            return explicitSpans
        }

        let tokens = RepairTokenization.taggedTokens(in: text)
        guard !tokens.isEmpty else { return explicitSpans }

        var spans: [SourceMoneySpan] = []
        var activeSymbol: String?
        var index = tokens.startIndex
        while index < tokens.endIndex {
            if let majorRun = numericRunBeforeUnit(startingAt: index, in: tokens, sourceText: text),
               majorRun.endIndex < tokens.endIndex,
               let majorValue = NumberEvidence.parsedValue(in: Array(tokens[majorRun.range].map(\.token))),
               let majorUnit = CurrencyUnits.unit(for: tokens[majorRun.endIndex].lemma),
               majorUnit.scale == .major {
                activeSymbol = majorUnit.symbol
                spans.append(SourceMoneySpan(
                    majorValue: majorValue,
                    minorValue: nil,
                    symbol: majorUnit.symbol
                ))
                index = majorRun.endIndex + 1
                continue
            }

            if let activeSymbol,
               activeSymbol == firstSymbol,
               spans.count < expectedCount,
               let run = numericRun(startingAt: index, in: tokens, sourceText: text),
               let majorValue = NumberEvidence.parsedValue(in: Array(tokens[run.range].map(\.token))) {
                spans.append(SourceMoneySpan(
                    majorValue: majorValue,
                    minorValue: nil,
                    symbol: activeSymbol
                ))
                index = run.endIndex
                continue
            }

            index += 1
        }

        return spans.count == expectedCount ? spans : explicitSpans
    }

    private func minorStartIndex(afterConjunctionAt conjunctionIndex: Int, in tokens: [RepairTaggedToken]) -> Int? {
        let maximumSkippedTokens = 2
        var index = conjunctionIndex + 1
        var skippedTokens = 0

        while index < tokens.endIndex {
            if RepairNumberParsing.isNumericToken(tokens[index]) {
                return index
            }
            if CurrencyUnits.unit(for: tokens[index].lemma) != nil {
                return nil
            }
            guard skippedTokens < maximumSkippedTokens else {
                return nil
            }
            skippedTokens += 1
            index += 1
        }

        return nil
    }

    private func numericRun(
        startingAt index: Int,
        in tokens: [RepairTaggedToken],
        sourceText: String
    ) -> (range: Range<Int>, endIndex: Int)? {
        guard index < tokens.endIndex, RepairNumberParsing.isNumericToken(tokens[index]) else { return nil }

        var endIndex = index + 1
        while endIndex < tokens.endIndex,
              isMoneyNumberRunSeparator(
                between: tokens[endIndex - 1].token,
                and: tokens[endIndex].token,
                in: sourceText
              ) {
            guard RepairNumberParsing.isNumericToken(tokens[endIndex])
                    || tokens[endIndex].tag == .conjunction
                    || numberPhraseCanContinue(
                        range: index...endIndex,
                        in: tokens
                    ) else {
                break
            }
            endIndex += 1
        }
        return (index..<endIndex, endIndex)
    }

    private func numericRunBeforeUnit(
        startingAt index: Int,
        in tokens: [RepairTaggedToken],
        sourceText: String
    ) -> (range: Range<Int>, endIndex: Int)? {
        guard index < tokens.endIndex, RepairNumberParsing.isNumericToken(tokens[index]) else { return nil }

        var bestRun: (range: Range<Int>, endIndex: Int)?
        var endIndex = index + 1
        while endIndex < tokens.endIndex {
            if CurrencyUnits.unit(for: tokens[endIndex].lemma) != nil,
               NumberEvidence.parsedValue(in: Array(tokens[index..<endIndex].map(\.token))) != nil {
                bestRun = (index..<endIndex, endIndex)
            }

            guard endIndex < tokens.endIndex,
                  isMoneyNumberRunSeparator(
                    between: tokens[endIndex - 1].token,
                    and: tokens[endIndex].token,
                    in: sourceText
                  ),
                  RepairNumberParsing.isNumericToken(tokens[endIndex])
                    || tokens[endIndex].tag == .conjunction
                    || numberPhraseCanContinue(
                        range: index...endIndex,
                        in: tokens
                    ) else {
                break
            }
            endIndex += 1
        }

        return bestRun ?? numericRun(startingAt: index, in: tokens, sourceText: sourceText)
    }

    private func numberPhraseCanContinue(range: ClosedRange<Int>, in tokens: [RepairTaggedToken]) -> Bool {
        NumberEvidence.parsedValue(in: Array(tokens[range].map(\.token))) != nil
    }

    private func isMoneyNumberRunSeparator(
        between left: RepairWordToken,
        and right: RepairWordToken,
        in text: String
    ) -> Bool {
        if RepairNumberParsing.isNumberRunSeparator(between: left, and: right, in: text) {
            return true
        }

        let separator = text[left.range.upperBound..<right.range.lowerBound]
        return separator == ","
            && left.text.allSatisfy(\.isNumber)
            && right.text.allSatisfy(\.isNumber)
            && right.text.count == 3
    }
}
