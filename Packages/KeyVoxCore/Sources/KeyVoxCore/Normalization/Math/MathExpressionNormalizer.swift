import Foundation

public struct MathExpressionNormalizer {
    public init() {}

    public func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let normalizedLines = lines.map(normalizeLine(_:))
        let normalized = normalizedLines.joined(separator: "\n")
        return stripTerminalPunctuationIfStandaloneMath(in: normalized)
    }

    private func normalizeLine(_ line: String) -> String {
        guard !line.isEmpty else { return line }
        guard containsMathTrigger(line) else { return line }

        var output = normalizeSpelledOutMathOperands(in: line)
        output = replaceMatches(in: output, using: Self.toThePowerOfRegex) { match, nsText in
            let base = nsText.substring(with: match.range(at: 1))
            let exponent = nsText.substring(with: match.range(at: 2))
            return "\(base)^\(exponent)"
        }
        output = replaceMatches(in: output, using: Self.toTheOrdinalPowerRegex) { match, nsText in
            let base = nsText.substring(with: match.range(at: 1))
            let rawExponent = nsText.substring(with: match.range(at: 2))
            guard let exponent = normalizedExponentToken(rawExponent) else { return nil }
            return "\(base)^\(exponent)"
        }
        output = replaceMatches(in: output, using: Self.raisedToRegex) { match, nsText in
            let base = nsText.substring(with: match.range(at: 1))
            let rawExponent = nsText.substring(with: match.range(at: 2))
            guard let exponent = normalizedExponentToken(rawExponent) else { return nil }
            return "\(base)^\(exponent)"
        }
        output = replaceMatches(in: output, using: Self.powerRegex) { match, nsText in
            let base = nsText.substring(with: match.range(at: 1))
            let exponent = nsText.substring(with: match.range(at: 2))
            return "\(base)^\(exponent)"
        }
        output = replaceMatches(in: output, using: Self.squaredRegex) { match, nsText in
            let value = nsText.substring(with: match.range(at: 1))
            return "\(value)^2"
        }
        output = replaceMatches(in: output, using: Self.cubedRegex) { match, nsText in
            let value = nsText.substring(with: match.range(at: 1))
            return "\(value)^3"
        }
        output = replaceMatches(in: output, using: Self.percentRegex) { match, nsText in
            let value = nsText.substring(with: match.range(at: 1))
            return "\(value)%"
        }
        output = replaceMatches(in: output, using: Self.multiplicationByXRegex) { _, _ in
            " * "
        }
        output = normalizeChainedOperatorWords(in: output)
        output = replaceMatches(in: output, using: Self.binaryOperatorRegex) { match, nsText in
            let lhs = nsText.substring(with: match.range(at: 1))
            let operatorWord = nsText.substring(with: match.range(at: 2)).lowercased()
            let rhs = nsText.substring(with: match.range(at: 3))
            guard let symbol = Self.symbol(forOperatorPhrase: operatorWord) else { return nil }
            return "\(lhs) \(symbol) \(rhs)"
        }
        output = replaceMatches(in: output, using: Self.equalsRegex) { match, nsText in
            let lhs = normalizeMathSymbolSpacing(nsText.substring(with: match.range(at: 1)))
            let rhs = nsText.substring(with: match.range(at: 2))
            return "\(lhs) = \(rhs)"
        }
        output = replaceMatches(in: output, using: Self.subtractionSymbolRegex) { _, _ in
            " - "
        }
        return output
    }
}

extension MathExpressionNormalizer {
    private func normalizeChainedOperatorWords(in text: String) -> String {
        var current = text
        for _ in 0..<Self.maxChainedOperatorPasses {
            let next = replaceMatches(in: current, using: Self.expressionOperatorRegex) { match, nsText in
                let lhs = normalizeMathSymbolSpacing(nsText.substring(with: match.range(at: 1)))
                let operatorWord = nsText.substring(with: match.range(at: 2)).lowercased()
                let rhs = nsText.substring(with: match.range(at: 3))
                guard let symbol = Self.symbol(forOperatorPhrase: operatorWord) else { return nil }
                return "\(lhs) \(symbol) \(rhs)"
            }
            if next == current {
                return current
            }
            current = next
        }
        return current
    }

    private func containsMathTrigger(_ line: String) -> Bool {
        guard let triggerRegex = Self.mathTriggerRegex else { return false }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        return triggerRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    private func normalizeMathSymbolSpacing(_ text: String) -> String {
        var output = text

        if let spacingRegex = Self.binarySymbolSpacingRegex {
            let range = NSRange(location: 0, length: (output as NSString).length)
            output = spacingRegex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: " $1 ")
        }

        if let exponentRegex = Self.exponentTighteningRegex {
            let range = NSRange(location: 0, length: (output as NSString).length)
            output = exponentRegex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "^")
        }

        if let collapseRegex = Self.whitespaceCollapseRegex {
            let collapsedRange = NSRange(location: 0, length: (output as NSString).length)
            output = collapseRegex.stringByReplacingMatches(in: output, options: [], range: collapsedRange, withTemplate: " ")
        }

        return output.trimmingCharacters(in: .whitespaces)
    }

    private static func symbol(forOperatorPhrase rawOperatorPhrase: String) -> String? {
        let normalized = rawOperatorPhrase
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return operatorWordToSymbol[normalized]
    }

    private func stripTerminalPunctuationIfStandaloneMath(in text: String) -> String {
        guard !text.contains("\n") else { return text }
        guard let trailingRegex = Self.trailingTerminalPunctuationRegex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let trailingMatch = trailingRegex.firstMatch(in: text, options: [], range: fullRange) else {
            return text
        }

        let coreRange = NSRange(location: 0, length: trailingMatch.range.location)
        let core = nsText.substring(with: coreRange).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !core.isEmpty else { return text }
        guard core.rangeOfCharacter(from: .letters) == nil else { return text }

        guard let allowedCharsRegex = Self.standaloneMathAllowedCharsRegex,
              let operatorRegex = Self.standaloneMathOperatorRegex else {
            return text
        }

        let coreNS = core as NSString
        let coreFullRange = NSRange(location: 0, length: coreNS.length)
        guard allowedCharsRegex.firstMatch(in: core, options: [], range: coreFullRange) != nil else {
            return text
        }
        guard operatorRegex.firstMatch(in: core, options: [], range: coreFullRange) != nil else {
            return text
        }
        guard core.rangeOfCharacter(from: .decimalDigits) != nil else { return text }

        return core
    }
}
