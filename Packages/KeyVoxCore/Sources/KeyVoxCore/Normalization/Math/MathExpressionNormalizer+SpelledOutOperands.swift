import Foundation

extension MathExpressionNormalizer {
    func normalizeSpelledOutMathOperands(in text: String) -> String {
        var output = text
        output = normalizeBinarySpelledOutOperands(in: output)
        output = normalizeUnarySpelledOutOperands(in: output)
        output = normalizeEqualsSpelledOutOperands(in: output)
        output = normalizePowerPhraseSpelledOutOperands(in: output)
        output = normalizeRaisedToBaseOperands(in: output)
        return output
    }

    private func normalizeBinarySpelledOutOperands(in text: String) -> String {
        normalizeSpelledOutOperands(
            in: text,
            phraseCandidates: Self.binaryOperatorTokenPhrases,
            requireLeadingOperand: true,
            requireTrailingOperand: true
        )
    }

    private func normalizeUnarySpelledOutOperands(in text: String) -> String {
        var output = text
        output = normalizeSpelledOutOperands(
            in: output,
            phraseCandidates: [Self.squaredTokenPhrase, Self.cubedTokenPhrase, Self.percentTokenPhrase],
            requireLeadingOperand: true,
            requireTrailingOperand: false
        )
        return output
    }

    private func normalizeEqualsSpelledOutOperands(in text: String) -> String {
        normalizeSpelledOutOperands(
            in: text,
            phraseCandidates: [Self.equalsTokenPhrase],
            requireLeadingOperand: true,
            requireTrailingOperand: true
        )
    }

    private func normalizePowerPhraseSpelledOutOperands(in text: String) -> String {
        var output = text
        output = normalizeSpelledOutOperands(
            in: output,
            phraseCandidates: [Self.toThePowerOfTokenPhrase, Self.powerOfTokenPhrase],
            requireLeadingOperand: true,
            requireTrailingOperand: true
        )
        return output
    }

    private func normalizeRaisedToBaseOperands(in text: String) -> String {
        normalizeSpelledOutOperands(
            in: text,
            phraseCandidates: [Self.raisedToTokenPhrase],
            requireLeadingOperand: true,
            requireTrailingOperand: false
        )
    }

    private func normalizeSpelledOutOperands(
        in text: String,
        phraseCandidates: [[String]],
        requireLeadingOperand: Bool,
        requireTrailingOperand: Bool
    ) -> String {
        var output = text

        while let replacement = firstSpelledOutOperandReplacement(
            in: output,
            phraseCandidates: phraseCandidates,
            requireLeadingOperand: requireLeadingOperand,
            requireTrailingOperand: requireTrailingOperand
        ) {
            output = applyReplacements(replacement, in: output)
        }

        return output
    }

    private func firstSpelledOutOperandReplacement(
        in text: String,
        phraseCandidates: [[String]],
        requireLeadingOperand: Bool,
        requireTrailingOperand: Bool
    ) -> [(range: NSRange, replacement: String)]? {
        let nsText = text as NSString
        let tokens = wordTokens(in: text)
        guard !tokens.isEmpty else { return nil }

        for tokenIndex in tokens.indices {
            for phrase in phraseCandidates {
                guard matchesPhrase(phrase, at: tokenIndex, in: tokens) else { continue }

                let phraseEndIndex = tokenIndex + phrase.count - 1
                let leadingOperand = trailingSpelledOutOperand(
                    endingBefore: tokenIndex,
                    in: tokens,
                    nsText: nsText
                )
                let trailingOperand = leadingSpelledOutOperand(
                    startingAfter: phraseEndIndex,
                    in: tokens,
                    nsText: nsText
                )

                let phraseRange = NSRange(
                    location: tokens[tokenIndex].range.location,
                    length: tokens[phraseEndIndex].range.upperBound - tokens[tokenIndex].range.location
                )
                let hasExistingLeadingOperand = existingMathOperandExistsBefore(phraseRange: phraseRange, nsText: nsText)
                let hasExistingTrailingOperand = existingMathOperandExistsAfter(phraseRange: phraseRange, nsText: nsText)

                if requireLeadingOperand && leadingOperand == nil && hasExistingLeadingOperand == false {
                    continue
                }
                if requireTrailingOperand && trailingOperand == nil && hasExistingTrailingOperand == false {
                    continue
                }

                var replacements: [(range: NSRange, replacement: String)] = []
                if let leadingOperand {
                    replacements.append((leadingOperand.range, leadingOperand.replacement))
                }
                if let trailingOperand,
                   replacements.contains(where: { NSEqualRanges($0.range, trailingOperand.range) }) == false {
                    replacements.append((trailingOperand.range, trailingOperand.replacement))
                }

                if replacements.isEmpty == false {
                    return replacements
                }
            }
        }

        return nil
    }

    private func applyReplacements(
        _ replacements: [(range: NSRange, replacement: String)],
        in text: String
    ) -> String {
        let mutable = NSMutableString(string: text)
        for replacement in replacements.sorted(by: { $0.range.location > $1.range.location }) {
            mutable.replaceCharacters(in: replacement.range, with: replacement.replacement)
        }
        return mutable as String
    }

    private func wordTokens(in text: String) -> [WordToken] {
        guard let regex = Self.wordTokenRegex else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: range).map { match in
            WordToken(range: match.range, text: nsText.substring(with: match.range))
        }
    }

    private func matchesPhrase(_ phrase: [String], at index: Int, in tokens: [WordToken]) -> Bool {
        guard index + phrase.count <= tokens.count else { return false }
        for offset in phrase.indices {
            if tokens[index + offset].normalized != phrase[offset] {
                return false
            }
        }
        return true
    }

    private func trailingSpelledOutOperand(
        endingBefore phraseStartIndex: Int,
        in tokens: [WordToken],
        nsText: NSString
    ) -> (range: NSRange, replacement: String)? {
        guard phraseStartIndex > 0 else { return nil }

        let endIndex = phraseStartIndex - 1
        var startIndex = endIndex
        while startIndex > 0,
              tokenGapIsOnlyWhitespace(between: tokens[startIndex - 1], and: tokens[startIndex], nsText: nsText) {
            startIndex -= 1
        }

        for candidateStartIndex in startIndex...endIndex {
            let candidateTokens = Array(tokens[candidateStartIndex...endIndex])
            guard let replacement = spelledOutReplacement(for: candidateTokens) else { continue }
            let range = NSRange(
                location: candidateTokens.first!.range.location,
                length: candidateTokens.last!.range.upperBound - candidateTokens.first!.range.location
            )
            return (range, replacement)
        }

        return nil
    }

    private func leadingSpelledOutOperand(
        startingAfter phraseEndIndex: Int,
        in tokens: [WordToken],
        nsText: NSString
    ) -> (range: NSRange, replacement: String)? {
        let startIndex = phraseEndIndex + 1
        guard startIndex < tokens.count else { return nil }

        var endIndex = startIndex
        while endIndex + 1 < tokens.count,
              tokenGapIsOnlyWhitespace(between: tokens[endIndex], and: tokens[endIndex + 1], nsText: nsText) {
            endIndex += 1
        }

        for candidateEndIndex in stride(from: endIndex, through: startIndex, by: -1) {
            let candidateTokens = Array(tokens[startIndex...candidateEndIndex])
            guard let replacement = spelledOutReplacement(for: candidateTokens) else { continue }
            let range = NSRange(
                location: candidateTokens.first!.range.location,
                length: candidateTokens.last!.range.upperBound - candidateTokens.first!.range.location
            )
            return (range, replacement)
        }

        return nil
    }

    private func tokenGapIsOnlyWhitespace(between lhs: WordToken, and rhs: WordToken, nsText: NSString) -> Bool {
        let gapRange = NSRange(location: lhs.range.upperBound, length: rhs.range.location - lhs.range.upperBound)
        guard gapRange.length >= 0 else { return false }
        let gap = nsText.substring(with: gapRange)
        return gap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func spelledOutReplacement(for tokens: [WordToken]) -> String? {
        let candidate = tokens.map(\.text).joined(separator: " ")
        let normalized = candidate
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let number = Self.spellOutNumberParser.number(from: normalized) else {
            return nil
        }

        let resolvedNumber = resolvedSpelledOutNumber(from: tokens, direct: number)
        let doubleValue = resolvedNumber.doubleValue
        if doubleValue.rounded(.towardZero) == doubleValue {
            return String(resolvedNumber.intValue)
        }

        return resolvedNumber.stringValue
    }

    private func resolvedSpelledOutNumber(from tokens: [WordToken], direct number: NSNumber) -> NSNumber {
        guard tokens.count == 2 else { return number }

        let normalizedTokens = tokens.map {
            $0.text
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let lhs = Self.spellOutNumberParser.number(from: normalizedTokens[0]),
              let rhs = Self.spellOutNumberParser.number(from: normalizedTokens[1]) else {
            return number
        }

        let whole = number.intValue
        let lhsValue = lhs.intValue
        let rhsValue = rhs.intValue

        guard whole == lhsValue * 100 + rhsValue else {
            return number
        }

        return NSNumber(value: lhsValue + rhsValue)
    }

    private func existingMathOperandExistsBefore(phraseRange: NSRange, nsText: NSString) -> Bool {
        guard phraseRange.location > 0 else { return false }
        let prefix = nsText.substring(to: phraseRange.location)
        guard let last = prefix.trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return false
        }
        return last.isNumber || last == ")" || last == "%"
    }

    private func existingMathOperandExistsAfter(phraseRange: NSRange, nsText: NSString) -> Bool {
        let suffixStart = phraseRange.upperBound
        guard suffixStart < nsText.length else { return false }
        let suffix = nsText.substring(from: suffixStart)
        guard let first = suffix.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return false
        }
        return first.isNumber || first == "(" || first == "-"
    }
}
