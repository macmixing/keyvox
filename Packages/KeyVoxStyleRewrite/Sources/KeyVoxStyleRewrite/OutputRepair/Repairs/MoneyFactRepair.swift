import Foundation

struct MoneyFactRepair {
    private struct SourceMoneySpan {
        let majorValue: Int
        let minorValue: Int?
        let symbol: String
    }

    func repair(original: String, rewritten: String) -> String {
        let sourceSpans = sourceMoneySpans(in: original)
        guard !sourceSpans.isEmpty else { return rewritten }

        let splitRepaired = repairSplitMoneyAmount(sourceSpans: sourceSpans, rewritten: rewritten)
        let amountDriftRepaired = repairSingleMoneyAmountDrift(sourceSpans: sourceSpans, rewritten: splitRepaired)
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
            return formattedMoneyAmount(symbol: symbol, sourceSpan: sourceSpan)
        }
    }

    private func repairSingleMoneyAmountDrift(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        guard sourceSpans.count == 1, let sourceSpan = sourceSpans.first else { return rewritten }

        return RepairMatching.replacingMatches(
            in: rewritten,
            pattern: "(\(CurrencyUnits.symbolPattern))\\s*(\\d+)(?:\\.(\\d{1,2}))?(?!\\d|\\.\\d)",
            options: []
        ) { match, nsText in
            guard match.numberOfRanges == 4 else { return nil }
            let symbol = nsText.substring(with: match.range(at: 1))
            guard symbol == sourceSpan.symbol else { return nil }
            guard let major = Int(nsText.substring(with: match.range(at: 2))) else { return nil }

            let minorRange = match.range(at: 3)
            let minor = minorRange.location == NSNotFound
                ? nil
                : Int(nsText.substring(with: minorRange).padding(toLength: 2, withPad: "0", startingAt: 0))
            guard major != sourceSpan.majorValue || minor != sourceSpan.minorValue else {
                return nil
            }

            return formattedMoneyAmount(symbol: symbol, sourceSpan: sourceSpan)
        }
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

            return formattedMoneyAmount(symbol: symbol, sourceSpan: sourceSpan)
        }
    }

    private func formattedMoneyAmount(symbol: String, sourceSpan: SourceMoneySpan) -> String {
        if let minorValue = sourceSpan.minorValue {
            return "\(symbol)\(sourceSpan.majorValue).\(String(format: "%02d", minorValue))"
        }
        return "\(symbol)\(sourceSpan.majorValue)"
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
              RepairNumberParsing.isNumberRunSeparator(
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
                  RepairNumberParsing.isNumberRunSeparator(
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
}
