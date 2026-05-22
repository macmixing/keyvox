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
        guard splitRepaired == rewritten else {
            return splitRepaired
        }

        return repairSingleMoneyAmountDrift(sourceSpans: sourceSpans, rewritten: rewritten)
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
            guard let majorRun = numericRun(startingAt: index, in: tokens, sourceText: text),
                  majorRun.endIndex < tokens.endIndex,
                  let majorValue = parsedNumericRun(Array(tokens[majorRun.range])),
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
               let minorRun = numericRun(startingAt: minorStartIndex, in: tokens, sourceText: text),
               minorRun.endIndex < tokens.endIndex,
               let parsedMinorValue = parsedNumericRun(Array(tokens[minorRun.range])),
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
              RepairNumberParsing.isNumericToken(tokens[endIndex]),
              RepairNumberParsing.isNumberRunSeparator(
                between: tokens[endIndex - 1].token,
                and: tokens[endIndex].token,
                in: sourceText
              ) {
            endIndex += 1
        }
        return (index..<endIndex, endIndex)
    }

    private func parsedNumericRun(_ tokens: [RepairTaggedToken]) -> Int? {
        let texts = tokens.map(\.token.text)
        if texts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return Int(texts.joined())
        }
        if let digitSequence = RepairNumberParsing.parsedDigitSequence(from: texts) {
            return digitSequence
        }
        return RepairNumberParsing.parsedSpellOutInteger(texts.joined(separator: " "))
    }
}
