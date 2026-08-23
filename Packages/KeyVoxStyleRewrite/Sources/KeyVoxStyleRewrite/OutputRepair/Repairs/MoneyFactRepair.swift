import Foundation

struct MoneyFactRepair {
    private struct SourceMoneySpan {
        let majorValue: Int
        let minorValue: Int?
        let symbol: String
        let range: Range<String.Index>?

        init(
            majorValue: Int,
            minorValue: Int?,
            symbol: String,
            range: Range<String.Index>? = nil
        ) {
            self.majorValue = majorValue
            self.minorValue = minorValue
            self.symbol = symbol
            self.range = range
        }
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

        let splitMajorRepaired = repairSplitMajorMoneyAmount(sourceSpans: sourceSpans, rewritten: rewritten)
        let splitRepaired = repairSplitMoneyAmount(sourceSpans: sourceSpans, rewritten: splitMajorRepaired)
        let multipleAmountDriftRepaired = repairMultipleMoneyAmountDrift(
            sourceSpans: sourceMoneySpansIncludingImpliedMajorUnits(
                in: original,
                explicitSpans: sourceSpans,
                expectedCount: rewrittenMoneySpans(in: splitRepaired).count
            ),
            rewritten: splitRepaired
        )
        let prefixedAmountDriftRepaired = repairPrefixedMoneyAmountDrift(
            sourceSpans: sourceSpans,
            rewritten: multipleAmountDriftRepaired
        )
        let amountDriftRepaired = repairSingleMoneyAmountDrift(
            sourceSpans: sourceSpans,
            rewritten: prefixedAmountDriftRepaired
        )
        let redundantMinorUnitRepaired = repairRedundantMinorUnit(
            sourceSpans: sourceSpans,
            rewritten: amountDriftRepaired
        )
        return repairUnformattedMoneyAmount(
            sourceSpans: sourceSpans,
            rewritten: redundantMinorUnitRepaired
        )
    }

    private func repairSplitMajorMoneyAmount(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        guard sourceSpans.count == 1,
              let sourceSpan = sourceSpans.first,
              sourceSpan.minorValue == nil else {
            return rewritten
        }

        let rewrittenSpans = rewrittenMoneySpans(in: rewritten)
        guard rewrittenSpans.count == 2,
              rewrittenSpans.allSatisfy({ $0.symbol == sourceSpan.symbol }) else {
            return rewritten
        }

        let firstSpan = rewrittenSpans[0]
        let secondSpan = rewrittenSpans[1]
        let bridgeTokens = RepairTokenization.taggedTokens(in: rewritten).filter { token in
            token.token.range.lowerBound >= firstSpan.range.upperBound
                && token.token.range.upperBound <= secondSpan.range.lowerBound
        }
        guard bridgeTokens.count <= 3,
              bridgeTokens.contains(where: { $0.tag == .conjunction }) else {
            return rewritten
        }

        var repaired = rewritten
        repaired.replaceSubrange(
            firstSpan.range.lowerBound..<secondSpan.range.upperBound,
            with: formattedGroupedMoneyAmount(symbol: sourceSpan.symbol, sourceSpan: sourceSpan)
        )
        return repaired
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

    private func repairPrefixedMoneyAmountDrift(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        guard sourceSpans.count == 1,
              let sourceSpan = sourceSpans.first,
              sourceSpan.minorValue == nil else {
            return rewritten
        }

        let rewrittenSpans = rewrittenMoneySpans(in: rewritten)
        guard rewrittenSpans.count == 1,
              let rewrittenSpan = rewrittenSpans.first,
              rewrittenSpan.symbol == sourceSpan.symbol,
              let prefixedRange = prefixedMixedMoneyRange(
                  sourceSpan: sourceSpan,
                  rewrittenSpan: rewrittenSpan,
                  in: rewritten
              ) else {
            return rewritten
        }

        var repaired = rewritten
        repaired.replaceSubrange(
            prefixedRange,
            with: formattedGroupedMoneyAmount(symbol: sourceSpan.symbol, sourceSpan: sourceSpan)
        )
        return repaired
    }

    private func prefixedMixedMoneyRange(
        sourceSpan: SourceMoneySpan,
        rewrittenSpan: RewrittenMoneySpan,
        in rewritten: String
    ) -> Range<String.Index>? {
        let taggedTokens = RepairTokenization.taggedTokens(in: rewritten)
        let precedingTokens = taggedTokens.filter {
            $0.token.range.upperBound <= rewrittenSpan.range.lowerBound
        }
        guard let connector = precedingTokens.last,
              connector.tag == .conjunction,
              rewritten[connector.token.range.upperBound..<rewrittenSpan.range.lowerBound].allSatisfy(\.isWhitespace) else {
            return nil
        }

        var prefixTokens = [connector]
        var nextLowerBound = connector.token.range.lowerBound
        for token in precedingTokens.dropLast().reversed() {
            let separator = rewritten[token.token.range.upperBound..<nextLowerBound]
            guard separator.allSatisfy(\.isWhitespace) else { break }

            let isNumeric = RepairNumberParsing.numericValue(for: token.token) != nil
                || RepairNumberParsing.parsedSpellOutNumberPhraseWithImpliedUnit(token.token.text) != nil
            if isNumeric || token.tag == .determiner {
                prefixTokens.insert(token, at: prefixTokens.startIndex)
                nextLowerBound = token.token.range.lowerBound
                if token.tag == .determiner {
                    break
                }
            } else {
                break
            }
        }

        let numericPrefixTokens = prefixTokens
            .filter { $0.tag != .determiner }
            .map(\.token)
        let rewrittenMoneyTokens = RepairTokenization.wordTokens(
            in: String(rewritten[rewrittenSpan.range])
        )
        guard numericPrefixTokens.count >= 2,
              mixedGroupedMagnitudeValue(in: numericPrefixTokens + rewrittenMoneyTokens) == sourceSpan.majorValue,
              let firstPrefixToken = prefixTokens.first else {
            return nil
        }

        return firstPrefixToken.token.range.lowerBound..<rewrittenSpan.range.upperBound
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

    private func formattedGroupedMoneyAmount(symbol: String, sourceSpan: SourceMoneySpan) -> String {
        let majorText = groupedIntegerText(sourceSpan.majorValue)
        if let minorValue = sourceSpan.minorValue {
            return "\(symbol)\(majorText).\(String(format: "%02d", minorValue))"
        }
        return "\(symbol)\(majorText)"
    }

    private func groupedIntegerText(_ value: Int) -> String {
        let digits = String(value)
        var output = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset > 0, offset.isMultiple(of: 3) {
                output.insert(",", at: output.startIndex)
            }
            output.insert(character, at: output.startIndex)
        }
        return output
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

    private func moneyValues(in tokens: [RepairWordToken]) -> (majorValue: Int, minorValue: Int?)? {
        if let mixedGroupedMagnitudeValue = mixedGroupedMagnitudeValue(in: tokens) {
            return (mixedGroupedMagnitudeValue, nil)
        }

        if let decimalValues = decimalMoneyValues(in: tokens) {
            return decimalValues
        }

        if let evidence = NumberEvidence.components(in: tokens),
           let decimalText = NumberEvidence.decimalReplacementText(evidence: evidence, tokens: tokens),
           let separatorIndex = decimalText.firstIndex(of: ".") {
            let majorText = String(decimalText[..<separatorIndex])
            let minorText = String(decimalText[decimalText.index(after: separatorIndex)...])
            if !minorText.isEmpty,
               minorText.count <= 2,
               let majorValue = Int(majorText),
               let minorValue = Int(minorText.padding(toLength: 2, withPad: "0", startingAt: 0)) {
                return (majorValue, minorValue)
            }
        }

        guard let majorValue = NumberEvidence.parsedValue(in: tokens) else {
            return nil
        }
        return (majorValue, nil)
    }

    private func mixedGroupedMagnitudeValue(in tokens: [RepairWordToken]) -> Int? {
        let connectorIndices = tokens.indices.filter { index in
            RepairNumberParsing.numericValue(for: tokens[index]) == nil
                && RepairNumberParsing.parsedSpellOutNumberPhraseWithImpliedUnit(tokens[index].text) == nil
                && !RepairNumberParsing.isSpellOutDecimalSeparator(tokens[index])
        }
        guard connectorIndices.count == 1,
              let connectorIndex = connectorIndices.first,
              connectorIndex > tokens.startIndex,
              connectorIndex < tokens.index(before: tokens.endIndex) else {
            return nil
        }

        let leftTokens = Array(tokens[..<connectorIndex])
        let rightTokens = Array(tokens[(connectorIndex + 1)...])
        let leftText = leftTokens.map(\.text).joined(separator: " ")
        guard let leftValue = NumberEvidence.parsedValue(in: leftTokens)
                ?? RepairNumberParsing.parsedSpellOutNumberPhraseWithImpliedUnit(leftText),
              (100..<1_000).contains(leftValue),
              leftValue.isMultiple(of: 100),
              rightTokens.count >= 2,
              rightTokens[0].text.allSatisfy(\.isNumber),
              rightTokens.dropFirst().allSatisfy({ token in
                  token.text.count == 3 && token.text.allSatisfy(\.isNumber)
              }),
              let rightValue = Int(rightTokens.map(\.text).joined()) else {
            return nil
        }

        var scale = 1
        for _ in rightTokens.dropFirst() {
            let multiplied = scale.multipliedReportingOverflow(by: 1_000)
            guard !multiplied.overflow else { return nil }
            scale = multiplied.partialValue
        }
        let upperBound = scale.multipliedReportingOverflow(by: 1_000)
        guard !upperBound.overflow,
              leftValue < scale,
              rightValue >= scale,
              rightValue < upperBound.partialValue else {
            return nil
        }

        let scaledLeft = leftValue.multipliedReportingOverflow(by: scale)
        guard !scaledLeft.overflow else { return nil }
        let combined = scaledLeft.partialValue.addingReportingOverflow(rightValue)
        return combined.overflow ? nil : combined.partialValue
    }

    private func repairUnformattedMoneyAmount(sourceSpans: [SourceMoneySpan], rewritten: String) -> String {
        guard rewrittenMoneySpans(in: rewritten).isEmpty else { return rewritten }

        let rewrittenSourceSpans = sourceMoneySpans(in: rewritten)
        guard rewrittenSourceSpans.count == sourceSpans.count,
              zip(sourceSpans, rewrittenSourceSpans).allSatisfy({ sourceSpan, rewrittenSpan in
                  sourceSpan.symbol == rewrittenSpan.symbol
                      && sourceSpan.majorValue == rewrittenSpan.majorValue
                      && sourceSpan.minorValue == rewrittenSpan.minorValue
                      && rewrittenSpan.range != nil
              }) else {
            return rewritten
        }

        var repaired = rewritten
        for (sourceSpan, rewrittenSpan) in zip(sourceSpans, rewrittenSourceSpans).reversed() {
            guard let range = rewrittenSpan.range else { continue }
            repaired.replaceSubrange(
                range,
                with: formattedGroupedMoneyAmount(symbol: sourceSpan.symbol, sourceSpan: sourceSpan)
            )
        }
        return repaired
    }

    private func decimalMoneyValues(in tokens: [RepairWordToken]) -> (majorValue: Int, minorValue: Int?)? {
        guard let separatorIndex = tokens.firstIndex(where: RepairNumberParsing.isSpellOutDecimalSeparator),
              separatorIndex > tokens.startIndex,
              separatorIndex < tokens.index(before: tokens.endIndex),
              tokens[(separatorIndex + 1)...].contains(where: RepairNumberParsing.isSpellOutDecimalSeparator) == false,
              let majorValue = NumberEvidence.parsedValue(in: Array(tokens[..<separatorIndex])) else {
            return nil
        }

        var minorParts: [String] = []
        for token in tokens[(separatorIndex + 1)...] {
            guard let value = RepairNumberParsing.numericValue(for: token),
                  (0..<100).contains(value) else {
                return nil
            }
            if token.text.allSatisfy(\.isNumber) {
                minorParts.append(token.text)
            } else {
                minorParts.append(String(value))
            }
        }

        let minorText = minorParts.joined()
        guard !minorText.isEmpty,
              minorText.count <= 2,
              let minorValue = Int(minorText.padding(toLength: 2, withPad: "0", startingAt: 0)) else {
            return nil
        }
        return (majorValue, minorValue)
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
                  let moneyValues = moneyValues(in: Array(tokens[majorRun.range].map(\.token))),
                  let majorUnit = CurrencyUnits.unit(for: tokens[majorRun.endIndex].lemma),
                  majorUnit.scale == .major else {
                index += 1
                continue
            }

            var minorValue = moneyValues.minorValue
            var nextIndex = majorRun.endIndex + 1
            if minorValue == nil,
               nextIndex < tokens.endIndex,
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

            let spanStartIndex: Int
            if majorRun.range.lowerBound > tokens.startIndex,
               tokens[majorRun.range.lowerBound - 1].tag == .determiner {
                spanStartIndex = majorRun.range.lowerBound - 1
            } else {
                spanStartIndex = majorRun.range.lowerBound
            }
            spans.append(SourceMoneySpan(
                majorValue: moneyValues.majorValue,
                minorValue: minorValue,
                symbol: majorUnit.symbol,
                range: tokens[spanStartIndex].token.range.lowerBound..<tokens[nextIndex - 1].token.range.upperBound
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
                    || RepairNumberParsing.isSpellOutDecimalSeparator(tokens[endIndex].token)
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
               moneyValues(in: Array(tokens[index..<endIndex].map(\.token))) != nil {
                bestRun = (index..<endIndex, endIndex)
            }

            guard endIndex < tokens.endIndex,
                  isMoneyNumberRunSeparator(
                    between: tokens[endIndex - 1].token,
                    and: tokens[endIndex].token,
                    in: sourceText
                  ),
                  RepairNumberParsing.isNumericToken(tokens[endIndex])
                    || RepairNumberParsing.isSpellOutDecimalSeparator(tokens[endIndex].token)
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
