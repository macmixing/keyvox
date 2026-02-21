import Foundation

struct MathExpressionNormalizer {
    private static let standaloneMathAllowedCharsRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^[\s0-9().+\-*/^=%]+$"#,
        options: []
    )
    private static let standaloneMathOperatorRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[+\-*/^=%]"#,
        options: []
    )
    private static let maxChainedOperatorPasses = 4
    private static let protectedEmailRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )
    private static let protectedURLRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:https?:\/\/|www\.)[^\s]+"#,
        options: []
    )
    private static let protectedDomainRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[A-Z0-9\-]+\.)+[A-Z]{2,}(?:\/[^\s]*)?"#,
        options: []
    )
    private static let protectedTimeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b\d{1,2}:\d{2}(?:\s?[AP]M)?\b"#,
        options: []
    )
    private static let protectedMalformedTimeWithMeridiemRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[1-9]|1[0-2])[.-][0-5][0-9](?:\s*(?:a\.?m\.?|am|a\.?n\.?|an|p\.?m\.?|pm))\b"#,
        options: []
    )
    private static let protectedMalformedTimeWithDaypartRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[1-9]|1[0-2])[.-][0-5][0-9](?=\s+(?:in the morning|this morning|in the afternoon|this afternoon|in the evening|this evening|at night|tonight)\b)"#,
        options: []
    )
    private static let protectedDateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{4}-\d{2}-\d{2}\b"#,
        options: []
    )
    private static let protectedVersionRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d+(?:\.\d+){2,}\b"#,
        options: []
    )
    private static let protectedCompactHyphenatedNumericRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{1,4}(?:-\d{1,4}){2,}\b"#,
        options: []
    )
    private static let mathTriggerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:plus|minus|subtract|subtracted\s+by|times|multiplied\s+by|divided\s+by|equals|percent|squared|cubed|power\s+of|to\s+the\s+power\s+of|to\s+the\s+[A-Z0-9\-]+\s+power|raised\s+to)\b|(?<=\d)\s*-\s*(?=\d)"#,
        options: []
    )
    private static let toThePowerOfRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+to\s+the\s+power\s+of\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    private static let toTheOrdinalPowerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+to\s+the\s+([A-Z0-9.\-]+)\s+power\b"#,
        options: []
    )
    private static let raisedToRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+raised\s+to\s+(?:the\s+)?([A-Z0-9.\-]+)(?:\s+power)?\b"#,
        options: []
    )
    private static let powerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+power\s+of\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    private static let squaredRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+squared\b"#,
        options: []
    )
    private static let cubedRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+cubed\b"#,
        options: []
    )
    private static let percentRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+percent\b"#,
        options: []
    )
    private static let multiplicationByXRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<=\d)\s*[x×]\s*(?=\d)"#,
        options: [.caseInsensitive]
    )
    private static let binaryOperatorRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+(plus|minus|subtract|subtracted\s+by|times|multiplied\s+by|divided\s+by)\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    private static let expressionOperatorRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b((?:\d|\()[0-9().+\-*/^%\s]*?\d)\s*,?\s*(plus|minus|subtract|subtracted\s+by|times|multiplied\s+by|divided\s+by)\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    private static let equalsRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?(?:\s*(?:\^|[+\-*/])\s*\d+(?:\.\d+)?)*)\s+equals\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    private static let subtractionSymbolRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<=\d)\s*-\s*(?=\d)"#,
        options: []
    )
    private static let binarySymbolSpacingRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s*([+\-*/=])\s*"#,
        options: []
    )
    private static let exponentTighteningRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s*\^\s*"#,
        options: []
    )
    private static let whitespaceCollapseRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s{2,}"#,
        options: []
    )
    private static let trailingTerminalPunctuationRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[.!?]+\s*$"#,
        options: []
    )
    private static let numericOrdinalExponentRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^(\d+)(?:st|nd|rd|th)?$"#,
        options: []
    )
    private static let ordinalWordToExponent: [String: String] = [
        "first": "1",
        "second": "2",
        "third": "3",
        "fourth": "4",
        "fifth": "5",
        "sixth": "6",
        "seventh": "7",
        "eighth": "8",
        "ninth": "9",
        "tenth": "10",
        "eleventh": "11",
        "twelfth": "12",
        "thirteenth": "13",
        "fourteenth": "14",
        "fifteenth": "15",
        "sixteenth": "16",
        "seventeenth": "17",
        "eighteenth": "18",
        "nineteenth": "19",
        "twentieth": "20"
    ]

    func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }
        guard text.rangeOfCharacter(from: .decimalDigits) != nil else { return text }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let normalizedLines = lines.map(normalizeLine(_:))
        let normalized = normalizedLines.joined(separator: "\n")
        return stripTerminalPunctuationIfStandaloneMath(in: normalized)
    }

    private func normalizeLine(_ line: String) -> String {
        guard !line.isEmpty else { return line }
        guard containsMathTrigger(line) else { return line }
        guard !isLikelyCodeishLine(line) else { return line }

        var output = line
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
            let symbol: String
            switch operatorWord {
            case "plus":
                symbol = "+"
            case "minus", "subtract", "subtracted by":
                symbol = "-"
            case "times", "multiplied by":
                symbol = "*"
            case "divided by":
                symbol = "/"
            default:
                return nil
            }
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

    private func normalizeChainedOperatorWords(in text: String) -> String {
        var current = text
        for _ in 0..<Self.maxChainedOperatorPasses {
            let next = replaceMatches(in: current, using: Self.expressionOperatorRegex) { match, nsText in
                let lhs = normalizeMathSymbolSpacing(nsText.substring(with: match.range(at: 1)))
                let operatorWord = nsText.substring(with: match.range(at: 2)).lowercased()
                let rhs = nsText.substring(with: match.range(at: 3))
                let symbol: String
                switch operatorWord {
                case "plus":
                    symbol = "+"
                case "minus", "subtract", "subtracted by":
                    symbol = "-"
                case "times", "multiplied by":
                    symbol = "*"
                case "divided by":
                    symbol = "/"
                default:
                    return nil
                }
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

    private func isLikelyCodeishLine(_ line: String) -> Bool {
        CodeishLineDetector.isLikelyCodeishLine(line)
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

    private func replaceMatches(
        in text: String,
        using regex: NSRegularExpression?,
        transform: (_ match: NSTextCheckingResult, _ nsText: NSString) -> String?
    ) -> String {
        guard let regex else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return text }

        let protectedRanges = protectedRanges(in: text)
        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            if intersectsProtectedRange(match.range, protectedRanges: protectedRanges) {
                continue
            }
            guard let replacement = transform(match, nsText) else { continue }
            mutable.replaceCharacters(in: match.range, with: replacement)
        }

        return mutable as String
    }

    private func protectedRanges(in text: String) -> [NSRange] {
        var protected: [NSRange] = []
        protected.append(contentsOf: ranges(matching: Self.protectedEmailRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedURLRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedDomainRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedTimeRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedMalformedTimeWithMeridiemRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedMalformedTimeWithDaypartRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedDateRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedVersionRegex, in: text))
        protected.append(contentsOf: compactHyphenatedNumericRanges(in: text))
        return protected
    }

    private func compactHyphenatedNumericRanges(in text: String) -> [NSRange] {
        guard let regex = Self.protectedCompactHyphenatedNumericRegex else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, options: [], range: fullRange)
            .map(\.range)
            .filter { range in
                let token = nsText.substring(with: range)
                let segments = token.split(separator: "-", omittingEmptySubsequences: true)
                return segments.contains { $0.count >= 3 }
            }
    }

    private func ranges(matching regex: NSRegularExpression?, in text: String) -> [NSRange] {
        guard let regex else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: fullRange).map(\.range)
    }

    private func intersectsProtectedRange(_ range: NSRange, protectedRanges: [NSRange]) -> Bool {
        for protected in protectedRanges where NSIntersectionRange(range, protected).length > 0 {
            return true
        }
        return false
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

    private func normalizedExponentToken(_ token: String) -> String? {
        let trimmed = token
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}.,;:!?"))
        guard !trimmed.isEmpty else { return nil }

        if let value = Self.ordinalWordToExponent[trimmed] {
            return value
        }

        if let regex = Self.numericOrdinalExponentRegex {
            let nsToken = trimmed as NSString
            let range = NSRange(location: 0, length: nsToken.length)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                return nsToken.substring(with: match.range(at: 1))
            }
        }

        return nil
    }
}
