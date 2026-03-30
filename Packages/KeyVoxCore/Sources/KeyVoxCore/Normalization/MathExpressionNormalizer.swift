import Foundation

public struct MathExpressionNormalizer {
    private struct WordToken {
        let range: NSRange
        let text: String

        var normalized: String {
            text.lowercased()
        }
    }

    private static let operatorWordToSymbol: [String: String] = [
        "plus": "+",
        "minus": "-",
        "subtract": "-",
        "subtracted by": "-",
        "times": "*",
        "multiplied by": "*",
        "divided by": "/"
    ]
    private static let operatorWordAlternation: String = {
        operatorWordToSymbol.keys
            .sorted { $0.count > $1.count }
            .map { key in
                NSRegularExpression.escapedPattern(for: key)
                    .replacingOccurrences(of: " ", with: #"\s+"#)
            }
            .joined(separator: "|")
    }()
    private static let spellOutNumberParser: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        return formatter
    }()
    private static let wordTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b[\p{L}]+(?:-[\p{L}]+)*\b"#,
        options: []
    )
    private static let binaryOperatorTokenPhrases: [[String]] = operatorWordToSymbol.keys
        .map { $0.split(separator: " ").map(String.init) }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.joined(separator: " ").count > rhs.joined(separator: " ").count
        }
    private static let equalsTokenPhrase = ["equals"]
    private static let squaredTokenPhrase = ["squared"]
    private static let cubedTokenPhrase = ["cubed"]
    private static let percentTokenPhrase = ["percent"]
    private static let toThePowerOfTokenPhrase = ["to", "the", "power", "of"]
    private static let powerOfTokenPhrase = ["power", "of"]
    private static let raisedToTokenPhrase = ["raised", "to"]
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
        pattern: #"(?i)\b(?:[1-9]|1[0-2])\s*[.-]\s*[0-5][0-9](?:[\s-]*(?:a[\s.-]*m\.?|a[\s.-]*n\.?|p[\s.-]*m\.?))\b"#,
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
    private static let protectedPhoneRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:\d{3}\s*-\s*)?\d{3}\s*-\s*\d{4}\b"#,
        options: []
    )
    private static let protectedCompactHyphenatedNumericRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{1,4}(?:-\d{1,4}){2,}\b"#,
        options: []
    )
    private static let mathTriggerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?i)\\b(?:\(operatorWordAlternation)|equals|percent|squared|cubed|power\\s+of|to\\s+the\\s+power\\s+of|to\\s+the\\s+[A-Z0-9\\-.]+(?:\\s+[A-Z0-9\\-.]+)*\\s+power|raised\\s+to)\\b|(?<=\\d)\\s*-\\s*(?=\\d)",
        options: []
    )
    private static let toThePowerOfRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+to\s+the\s+power\s+of\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    private static let toTheOrdinalPowerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+to\s+the\s+([A-Z0-9.\-]+(?:\s+[A-Z0-9.\-]+)*)\s+power\b"#,
        options: []
    )
    private static let raisedToRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+raised\s+to\s+(?:the\s+)?([A-Z0-9.\-]+(?:\s+[A-Z0-9.\-]+)*)(?:\s+power)?\b"#,
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
        pattern: "(?i)\\b(\\d+(?:\\.\\d+)?)\\s+(\(operatorWordAlternation))\\s+(\\d+(?:\\.\\d+)?)\\b",
        options: []
    )
    private static let expressionOperatorRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?i)\\b((?:\\d|\\()[0-9().+\\-*/^%\\s]*?\\d)\\s*,?\\s*(\(operatorWordAlternation))\\s+(\\d+(?:\\.\\d+)?)\\b",
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

    private func normalizeSpelledOutMathOperands(in text: String) -> String {
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

        let doubleValue = number.doubleValue
        if doubleValue.rounded(.towardZero) == doubleValue {
            return String(number.intValue)
        }

        return number.stringValue
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
        protected.append(contentsOf: ranges(matching: Self.protectedPhoneRegex, in: text))
        protected.append(contentsOf: compactHyphenatedNumericRanges(in: text))
        return protected
    }

    private func compactHyphenatedNumericRanges(in text: String) -> [NSRange] {
        guard let regex = Self.protectedCompactHyphenatedNumericRegex else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, options: [], range: fullRange).map(\.range)
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
        let exponentToken = trimmed.replacingOccurrences(
            of: #"\s+power$"#,
            with: "",
            options: .regularExpression
        )
        guard !exponentToken.isEmpty else { return nil }

        if let regex = Self.numericOrdinalExponentRegex {
            let nsToken = exponentToken as NSString
            let range = NSRange(location: 0, length: nsToken.length)
            if let match = regex.firstMatch(in: exponentToken, options: [], range: range) {
                return nsToken.substring(with: match.range(at: 1))
            }
        }

        return Self.parseOrdinalWordExponent(exponentToken)
    }

    private static func parseOrdinalWordExponent(_ text: String) -> String? {
        let normalized = normalizedOrdinalLookupKey(text)
        guard !normalized.isEmpty else { return nil }

        if let direct = spellOutNumberParser.number(from: normalized)?.intValue, direct > 0 {
            return String(direct)
        }

        let parts = normalized.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }

        let prefix = parts.dropLast().joined(separator: " ")
        let suffix = parts.last ?? ""
        guard let prefixValue = spellOutNumberParser.number(from: prefix)?.intValue,
              prefixValue > 0,
              let suffixValue = spellOutNumberParser.number(from: suffix)?.intValue,
              suffixValue > 0 else {
            return nil
        }

        return String(prefixValue + suffixValue)
    }

    private static func normalizedOrdinalLookupKey(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}.,;:!? ").union(.whitespacesAndNewlines))
    }
}
