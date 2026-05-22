import Foundation

enum RepairNumberParsing {
    static let apStyleNumeralLowerBound = 10

    private static let numberFormatterLocale = Locale(identifier: "en_US_POSIX")

    private static let spellOutNumberFormatter = numberFormatter(style: .spellOut)

    private static let ordinalNumberFormatter = numberFormatter(style: .ordinal)

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
        let candidates = [
            text,
            text.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression),
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

    static func isNumericToken(_ token: RepairTaggedToken) -> Bool {
        token.tag == .number
            || token.token.text.allSatisfy(\.isNumber)
            || parsedSpellOutInteger(token.token.text) != nil
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
}
