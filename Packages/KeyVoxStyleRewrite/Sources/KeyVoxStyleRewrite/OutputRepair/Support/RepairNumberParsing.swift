import Foundation

enum RepairNumberParsing {
    static let apStyleNumeralLowerBound = 10

    private static let spellOutNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        return formatter
    }()

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
