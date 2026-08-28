import Foundation

enum PocketTTSSpokenNumberNormalizer {
    private static let compactDollarThousandsPattern = #"\$([0-9]+)\s*[kK]\b"#
    private static let largeDollarAmountPattern = #"\$((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{4,}))(?!(?:[.,][0-9])|[\p{L}\p{N}%])"#
    private static let compactThousandsPattern = #"(?<![\p{L}\p{N}$])([0-9]+)\s*[kK]\b(?!%)"#
    private static let groupedNumberPattern = #"(?<![\p{L}\p{N}$.,])([0-9]{1,3}(?:,[0-9]{3})+)(?!(?:[.,][0-9])|[\p{L}\p{N}%])"#

    static func normalize(in text: String) -> String {
        let normalizedDollarThousands = replacingMatches(
            in: text,
            pattern: compactDollarThousandsPattern
        ) { digits in
            guard let value = scaledThousands(from: digits) else { return nil }
            return spokenValue(value).map { "\($0) dollars" }
        }

        let normalizedLargeDollarAmounts = replacingMatches(
            in: normalizedDollarThousands,
            pattern: largeDollarAmountPattern
        ) { digits in
            guard let value = integer(from: digits) else { return nil }
            return spokenValue(value).map { "\($0) dollars" }
        }

        let normalizedCompactThousands = replacingMatches(
            in: normalizedLargeDollarAmounts,
            pattern: compactThousandsPattern
        ) { digits in
            guard let value = scaledThousands(from: digits) else { return nil }
            return spokenValue(value)
        }

        return replacingMatches(
            in: normalizedCompactThousands,
            pattern: groupedNumberPattern
        ) { digits in
            guard let value = integer(from: digits) else { return nil }
            return spokenValue(value)
        }
    }

    private static func integer(from digits: String) -> Int64? {
        Int64(digits.replacingOccurrences(of: ",", with: ""))
    }

    private static func scaledThousands(from digits: String) -> Int64? {
        guard let value = Int64(digits) else { return nil }

        let scaledValue = value.multipliedReportingOverflow(by: 1_000)
        guard scaledValue.overflow == false else { return nil }
        return scaledValue.partialValue
    }

    private static func spokenValue(_ value: Int64) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: value))
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        replacement: (String) -> String?
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
                let captureRange = Range(match.range(at: 1), in: text),
                let replacementText = replacement(String(text[captureRange]))
            else {
                continue
            }

            normalized.replaceSubrange(matchRange, with: replacementText)
        }

        return normalized
    }
}
