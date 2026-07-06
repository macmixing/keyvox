import Foundation

enum RepairNumberParsing {
    static let apStyleNumeralLowerBound = 10

    private static let numberFormatterLocale = Locale(identifier: "en_US_POSIX")

    private static let spellOutNumberFormatter = numberFormatter(style: .spellOut)

    private static let ordinalNumberFormatter = numberFormatter(style: .ordinal)

    private static let spellOutDecimalSeparatorToken: String? = {
        let unit = apStyleNumeralLowerBound / apStyleNumeralLowerBound
        let decimal = Double(unit) + (Double(unit) / Double(apStyleNumeralLowerBound))
        guard let spellOutDecimal = spellOutNumberFormatter.string(from: NSNumber(value: decimal)),
              let unitText = spellOutString(for: unit) else {
            return nil
        }

        return normalizedSpellOut(spellOutDecimal)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .first { $0 != normalizedSpellOut(unitText) }
    }()

    private static func numberFormatter(style: NumberFormatter.Style) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = numberFormatterLocale
        formatter.numberStyle = style
        return formatter
    }

    static func spellOutString(for value: Int) -> String? {
        spellOutNumberFormatter.string(from: NSNumber(value: value))
    }

    static func parsedSpellOutInteger(_ text: String) -> Int? {
        let normalizedText = text.lowercased()
        let candidates = [
            normalizedText,
            normalizedText.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression),
        ]

        for candidate in candidates {
            guard let number = spellOutNumberFormatter.number(from: candidate),
                  let value = integerValue(from: number),
                  spellOutMatches(candidate, value: value) else {
                continue
            }
            return value
        }

        return nil
    }

    static func parsedSpellOutNumberPhrase(_ text: String) -> Int? {
        let normalizedText = text.lowercased()
        let candidates = [
            normalizedText,
            normalizedText.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression),
        ]

        for candidate in candidates {
            guard let number = spellOutNumberFormatter.number(from: candidate),
                  let value = integerValue(from: number),
                  spellOutNumberPhraseMatches(candidate, value: value) else {
                continue
            }
            return value
        }

        return nil
    }

    static func parsedSpellOutNumberPhraseByChunks(_ text: String) -> Int? {
        let tokens = normalizedSpellOut(text).split(separator: " ").map(String.init)
        guard tokens.count > 1 else { return nil }

        var values: [Int] = []
        var index = tokens.startIndex
        while index < tokens.endIndex {
            var parsed: (endIndex: Int, value: Int)?
            var endIndex = tokens.endIndex
            while endIndex > index {
                let candidate = tokens[index..<endIndex].joined(separator: " ")
                if let value = parsedSpellOutNumberPhrase(candidate)
                    ?? parsedSpellOutInteger(candidate) {
                    parsed = (endIndex, value)
                    break
                }
                endIndex -= 1
            }

            if let parsed {
                values.append(parsed.value)
                index = parsed.endIndex
            } else {
                index += 1
            }
        }

        guard values.count > 1 else { return nil }
        return values.reduce(0, +)
    }

    static func parsedOrdinalInteger(_ text: String) -> Int? {
        let normalizedText = text.lowercased()

        if let ordinalNumber = ordinalNumberFormatter.number(from: normalizedText),
           let ordinalValue = integerValue(from: ordinalNumber) {
            return ordinalValue
        }

        let candidates = [
            normalizedText,
            normalizedText.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression),
        ]

        for candidate in candidates {
            guard let number = spellOutNumberFormatter.number(from: candidate),
                  let value = integerValue(from: number) else {
                continue
            }
            return value
        }

        return nil
    }

    static func ordinalString(for value: Int) -> String? {
        ordinalNumberFormatter.string(from: NSNumber(value: value))
    }

    static func numericValue(for token: RepairWordToken) -> Int? {
        if token.text.allSatisfy(\.isNumber) {
            return Int(token.text)
        }
        return parsedSpellOutInteger(token.text)
    }

    static func parsedDigitSequence(from tokenTexts: [String]) -> Int? {
        var digits = ""
        for text in tokenTexts {
            guard let value = parsedSpellOutInteger(text), (0...9).contains(value) else {
                return nil
            }
            digits += String(value)
        }
        return Int(digits)
    }

    static func parsedConnectorNumberRun(_ tokens: [RepairWordToken]) -> Int? {
        guard tokens.count >= 3,
              isSingleNumberToken(tokens[tokens.startIndex]),
              isSingleNumberToken(tokens[tokens.index(before: tokens.endIndex)]) else {
            return nil
        }

        for connectorIndex in tokens.indices.dropFirst().dropLast()
        where !isSingleNumberToken(tokens[connectorIndex]) {
            let leftTokens = tokens[tokens.startIndex..<connectorIndex]
            let rightTokens = tokens[tokens.index(after: connectorIndex)..<tokens.endIndex]
            let hundredsBoundary = apStyleNumeralLowerBound * apStyleNumeralLowerBound
            guard let leftValue = parsedNumberChunk(leftTokens),
                  let rightValue = parsedNumberChunk(rightTokens),
                  leftValue >= hundredsBoundary,
                  leftValue.isMultiple(of: hundredsBoundary),
                  (1..<hundredsBoundary).contains(rightValue) else {
                continue
            }
            return leftValue + rightValue
        }

        return nil
    }

    static func isNumericToken(_ token: RepairTaggedToken) -> Bool {
        token.tag == .number
            || token.token.text.allSatisfy(\.isNumber)
            || parsedSpellOutInteger(token.token.text) != nil
    }

    static func isSpellOutDecimalSeparator(_ token: RepairWordToken) -> Bool {
        guard let spellOutDecimalSeparatorToken else {
            return false
        }

        return token.normalized == spellOutDecimalSeparatorToken
            || token.normalized == "\(spellOutDecimalSeparatorToken)s"
    }

    static func isNumberRunSeparator(between left: RepairWordToken, and right: RepairWordToken, in text: String) -> Bool {
        let separator = text[left.range.upperBound..<right.range.lowerBound]
        return separator.allSatisfy { $0.isWhitespace || $0 == "-" }
    }

    private static func integerValue(from number: NSNumber) -> Int? {
        let doubleValue = number.doubleValue
        guard doubleValue.isFinite,
              doubleValue.rounded() == doubleValue,
              doubleValue >= Double(Int.min),
              doubleValue <= Double(Int.max) else {
            return nil
        }
        return Int(doubleValue)
    }

    private static func spellOutMatches(_ text: String, value: Int) -> Bool {
        guard let spellOut = spellOutString(for: value) else {
            return false
        }

        return normalizedSpellOut(text) == normalizedSpellOut(spellOut)
    }

    private static func normalizedSpellOut(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func isSingleNumberToken(_ token: RepairWordToken) -> Bool {
        parsedSpellOutInteger(token.text) != nil
    }

    private static func parsedNumberChunk(_ tokens: ArraySlice<RepairWordToken>) -> Int? {
        let text = tokens.map(\.text).joined(separator: " ")
        return parsedSpellOutNumberPhrase(text)
            ?? parsedSpellOutInteger(text)
    }

    private static func spellOutNumberPhraseMatches(_ text: String, value: Int) -> Bool {
        guard let spellOut = spellOutString(for: value) else {
            return false
        }

        let sourceTokens = normalizedSpellOut(text).split(separator: " ").map(String.init)
        let canonicalTokens = normalizedSpellOut(spellOut).split(separator: " ").map(String.init)
        guard !sourceTokens.isEmpty, !canonicalTokens.isEmpty else {
            return false
        }

        var canonicalIndex = 0
        for sourceToken in sourceTokens {
            if canonicalIndex < canonicalTokens.count,
               sourceToken == canonicalTokens[canonicalIndex] {
                canonicalIndex += 1
            } else if parsedSpellOutInteger(sourceToken) != nil {
                return false
            }
        }

        return canonicalIndex == canonicalTokens.count
    }
}
