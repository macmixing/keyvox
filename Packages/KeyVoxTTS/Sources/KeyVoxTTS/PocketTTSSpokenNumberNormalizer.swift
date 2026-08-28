import Foundation

enum PocketTTSSpokenNumberNormalizer {
    private static let decimalDollarAmountPattern = #"\$((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+))\.([0-9]{1,2})(?![\p{L}\p{N}%]|\.[0-9])"#
    private static let compactDollarThousandsPattern = #"\$([0-9]+(?:\.[0-9]{1,3})?)\s*[kK]\b"#
    private static let largeDollarAmountPattern = #"\$((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{4,}))(?!(?:[.,][0-9])|[\p{L}\p{N}%])"#
    private static let compactThousandsPattern = #"(?<![\p{L}\p{N}$.,])([0-9]+(?:\.[0-9]{1,3})?)\s*k\b(?!%)"#
    private static let uppercaseCompactLabelPattern = #"(?<![\p{L}\p{N}$.,])([0-9]+(?:\.[0-9]{1,3})?)\s*K\b(?!%)"#
    private static let groupedNumberPattern = #"(?<![\p{L}\p{N}$.,])([0-9]{1,3}(?:,[0-9]{3})+)(?!(?:[.,][0-9])|[\p{L}\p{N}%])"#

    static func normalize(in text: String) -> String {
        let normalizedDecimalDollarAmounts = replacingMatches(
            in: text,
            pattern: decimalDollarAmountPattern
        ) { captures in
            guard
                captures.count == 2,
                let dollars = integer(from: captures[0]),
                let cents = cents(from: captures[1])
            else {
                return nil
            }

            return spokenCurrency(dollars: dollars, cents: cents)
        }

        let normalizedDollarThousands = replacingMatches(
            in: normalizedDecimalDollarAmounts,
            pattern: compactDollarThousandsPattern
        ) { captures in
            guard let digits = captures.first else { return nil }
            guard let value = scaledThousands(from: digits) else { return nil }
            return spokenValue(value).map { "\($0) dollars" }
        }

        let normalizedLargeDollarAmounts = replacingMatches(
            in: normalizedDollarThousands,
            pattern: largeDollarAmountPattern
        ) { captures in
            guard let digits = captures.first else { return nil }
            guard let value = integer(from: digits) else { return nil }
            return spokenValue(value).map { "\($0) dollars" }
        }

        let normalizedCompactThousands = replacingMatches(
            in: normalizedLargeDollarAmounts,
            pattern: compactThousandsPattern
        ) { captures in
            guard let digits = captures.first else { return nil }
            guard let value = scaledThousands(from: digits) else { return nil }
            return spokenValue(value)
        }

        let normalizedUppercaseCompactLabels = replacingMatches(
            in: normalizedCompactThousands,
            pattern: uppercaseCompactLabelPattern
        ) { captures in
            guard let digits = captures.first else { return nil }
            return spokenUppercaseCompactLabel(from: digits)
        }

        return replacingMatches(
            in: normalizedUppercaseCompactLabels,
            pattern: groupedNumberPattern
        ) { captures in
            guard let digits = captures.first else { return nil }
            guard let value = integer(from: digits) else { return nil }
            return spokenValue(value)
        }
    }

    private static func integer(from digits: String) -> Int64? {
        Int64(digits.replacingOccurrences(of: ",", with: ""))
    }

    private static func cents(from digits: String) -> Int64? {
        guard let value = Int64(digits) else { return nil }
        return digits.count == 1 ? value * 10 : value
    }

    private static func scaledThousands(from digits: String) -> Int64? {
        let components = digits.split(separator: ".", omittingEmptySubsequences: false)
        guard
            components.count <= 2,
            let wholeValue = Int64(components[0])
        else {
            return nil
        }

        let scaledWholeValue = wholeValue.multipliedReportingOverflow(by: 1_000)
        guard scaledWholeValue.overflow == false else { return nil }

        guard components.count == 2 else { return scaledWholeValue.partialValue }

        let fractionDigits = String(components[1])
        guard fractionDigits.isEmpty == false, fractionDigits.count <= 3 else {
            return nil
        }

        let paddedFraction = fractionDigits + String(
            repeating: "0",
            count: 3 - fractionDigits.count
        )
        guard let fractionValue = Int64(paddedFraction) else { return nil }

        let scaledValue = scaledWholeValue.partialValue.addingReportingOverflow(fractionValue)
        guard scaledValue.overflow == false else { return nil }
        return scaledValue.partialValue
    }

    private static func spokenValue(_ value: Int64) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: value))
    }

    private static func spokenCurrency(dollars: Int64, cents: Int64) -> String? {
        var components: [String] = []

        if dollars > 0 || cents == 0 {
            guard let spokenDollars = spokenValue(dollars) else { return nil }
            let unit = dollars == 1 ? "dollar" : "dollars"
            components.append("\(spokenDollars) \(unit)")
        }

        if cents > 0 {
            guard let spokenCents = spokenValue(cents) else { return nil }
            let unit = cents == 1 ? "cent" : "cents"
            components.append("\(spokenCents) \(unit)")
        }

        return components.joined(separator: " and ")
    }

    private static func spokenUppercaseCompactLabel(from digits: String) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .spellOut

        let value = NSDecimalNumber(
            string: digits,
            locale: Locale(identifier: "en_US")
        )
        guard let spokenValue = formatter.string(from: value) else { return nil }
        return "\(spokenValue) kay"
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        replacement: ([String]) -> String?
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        var normalized = text
        let matches = expression.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )

        for match in matches.reversed() {
            guard
                let matchRange = Range(match.range, in: normalized),
                match.numberOfRanges > 1
            else {
                continue
            }

            let captures = (1..<match.numberOfRanges).compactMap { index -> String? in
                guard let captureRange = Range(match.range(at: index), in: text) else {
                    return nil
                }
                return String(text[captureRange])
            }

            guard let replacementText = replacement(captures) else { continue }

            normalized.replaceSubrange(matchRange, with: replacementText)
        }

        return normalized
    }
}
