import Foundation

public struct TimeExpressionNormalizer {
    private static let spokenUnitValues: [String: Int] = [
        "one": 1,
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
        "six": 6,
        "seven": 7,
        "eight": 8,
        "nine": 9,
    ]

    private static let spokenTeenValues: [String: Int] = [
        "ten": 10,
        "eleven": 11,
        "twelve": 12,
        "thirteen": 13,
        "fourteen": 14,
        "fifteen": 15,
        "sixteen": 16,
        "seventeen": 17,
        "eighteen": 18,
        "nineteen": 19,
    ]

    private static let spokenTensValues: [String: Int] = [
        "twenty": 20,
        "thirty": 30,
        "forty": 40,
        "fifty": 50,
    ]

    private static let spokenHourValues: [String: Int] =
        spokenUnitValues.merging(
            [
                "ten": 10,
                "eleven": 11,
                "twelve": 12,
            ],
            uniquingKeysWith: { current, _ in current }
        )

    public init() {}

    public func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }

        let daypartPattern =
            "(?:in the morning|this morning|in the afternoon|this afternoon|in the evening|this evening|at night|tonight)"
        let spokenHourPattern = Self.spokenHourPattern
        let spokenMinutePattern = Self.spokenMinutePattern
        let amMeridiemPattern = "a[\\s\\.-]{0,3}(?:m\\.?|n\\.?)"
        let pmMeridiemPattern = "p[\\s\\.-]{0,3}m\\.?"
        let meridiemPattern = "(?:\(amMeridiemPattern)|\(pmMeridiemPattern))"

        var output = text

        output = replacingMeridiemMatches(
            pattern: #"\b(\#(spokenHourPattern))\s+(\#(spokenMinutePattern))[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hourWord = nsText.substring(with: match.range(at: 1))
            let minuteWords = nsText.substring(with: match.range(at: 2))
            guard let hour = spokenHourValue(hourWord),
                  let minute = spokenMinuteValue(minuteWords) else {
                return nil
            }

            return "\(hour):\(paddedMinute(minute))"
        }

        output = replacingMeridiemMatches(
            pattern: #"\b(\#(spokenHourPattern))[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hourWord = nsText.substring(with: match.range(at: 1))
            guard let hour = spokenHourValue(hourWord) else { return nil }
            return "\(hour):00"
        }

        // Normalize spaced/compact meridiem forms while preserving spoken structure.
        output = replacingMeridiemMatches(
            pattern: #"\b([1-9]|1[0-2]):([0-5][0-9])[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            return "\(hour):\(minute)"
        }

        output = replacingMeridiemMatches(
            pattern: #"\b([1-9]|1[0-2])\s*[\.-]\s*([0-5][0-9])[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            return "\(hour):\(minute)"
        }

        output = replacingMeridiemMatches(
            pattern: #"\b([0-9]{3,4})[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let digits = nsText.substring(with: match.range(at: 1))
            guard let formatted = formattedCompactTime(digits) else { return nil }
            return formatted
        }

        output = replacingMeridiemMatches(
            pattern: #"\b([1-9]|1[0-2])[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            return "\(hour):00"
        }

        // Balanced fuzzy-AM pass: map "AND" only when it behaves like a terminal meridiem token.
        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2])[:\.-]([0-5][0-9])[\s-]*and\.?(?=$|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            return "\(hour):\(minute) AM"
        }

        output = replacingMatches(
            pattern: #"\b([0-9]{3,4})[\s-]*and\.?(?=$|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let digits = nsText.substring(with: match.range(at: 1))
            guard let formatted = formattedCompactTime(digits) else { return nil }
            return "\(formatted) AM"
        }

        // Preserve spoken daypart phrases and only normalize malformed numeric time shape.
        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2])\s*[\.-]\s*([0-5][0-9])(?=\s+\#(daypartPattern)\b)"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            return "\(hour):\(minute)"
        }

        output = replacingMatches(
            pattern: #"\b([0-9]{3,4})(?=\s+\#(daypartPattern)\b)"#,
            in: output
        ) { match, nsText in
            let digits = nsText.substring(with: match.range(at: 1))
            return formattedCompactTime(digits)
        }

        return output
    }

    private func replacingMatches(
        pattern: String,
        in text: String,
        transform: (_ match: NSTextCheckingResult, _ nsText: NSString) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let nsText = text as NSString
        let mutable = NSMutableString(string: text)
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        for match in matches.reversed() {
            guard let replacement = transform(match, nsText) else { continue }
            mutable.replaceCharacters(in: match.range, with: replacement)
        }

        return mutable as String
    }

    private func replacingMeridiemMatches(
        pattern: String,
        in text: String,
        timeBuilder: (_ match: NSTextCheckingResult, _ nsText: NSString) -> String?
    ) -> String {
        replacingMatches(pattern: pattern, in: text) { match, nsText in
            guard let time = timeBuilder(match, nsText) else { return nil }
            let meridiemRangeIndex = match.numberOfRanges - 1
            return formattedTime(
                time,
                meridiem: nsText.substring(with: match.range(at: meridiemRangeIndex)),
                nsText: nsText,
                matchRange: match.range
            )
        }
    }

    private func formattedCompactTime(_ digits: String) -> String? {
        guard digits.count == 3 || digits.count == 4 else { return nil }

        let hourDigitsCount = digits.count - 2
        let hourStart = digits.startIndex
        let hourEnd = digits.index(hourStart, offsetBy: hourDigitsCount)
        let minuteStart = hourEnd
        let minuteEnd = digits.endIndex

        guard let hour = Int(digits[hourStart..<hourEnd]),
              let minute = Int(digits[minuteStart..<minuteEnd]),
              (1...12).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return "\(hour):\(String(format: "%02d", minute))"
    }

    private func spokenHourValue(_ value: String) -> Int? {
        Self.spokenHourValues[normalizedSpokenNumberToken(value)]
    }

    private func spokenMinuteValue(_ value: String) -> Int? {
        let normalized = normalizedSpokenNumberToken(value)
        let parts = spokenNumberParts(value)

        if parts.count == 2,
           parts[0] == "oh",
           let unitValue = Self.spokenUnitValues[parts[1]] {
            return unitValue
        }

        if let teenValue = Self.spokenTeenValues[normalized] {
            return teenValue
        }

        guard !parts.isEmpty else { return nil }

        if parts.count == 1 {
            return Self.spokenTensValues[parts[0]]
        }

        guard parts.count == 2,
              let tensValue = Self.spokenTensValues[parts[0]],
              let unitValue = Self.spokenUnitValues[parts[1]] else {
            return nil
        }

        return tensValue + unitValue
    }

    private func normalizedSpokenNumberToken(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func spokenNumberParts(_ value: String) -> [String] {
        value
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
            .map(String.init)
    }

    private func paddedMinute(_ minute: Int) -> String {
        String(format: "%02d", minute)
    }

    private func formattedTime(
        hour: String,
        minute: String,
        meridiem: String,
        nsText: NSString,
        matchRange: NSRange
    ) -> String {
        formattedTime(
            "\(hour):\(minute)",
            meridiem: meridiem,
            nsText: nsText,
            matchRange: matchRange
        )
    }

    private func formattedTime(
        _ time: String,
        meridiem: String,
        nsText: NSString,
        matchRange: NSRange
    ) -> String {
        let normalized = normalizedMeridiem(
            meridiem,
            preservingSentenceBoundaryIn: nsText,
            matchRange: matchRange
        )
        return "\(time) \(normalized)"
    }

    private static var spokenHourPattern: String {
        groupedAlternationPattern(for: Array(spokenHourValues.keys))
    }

    private static var spokenMinutePattern: String {
        let unitPattern = groupedAlternationPattern(for: Array(spokenUnitValues.keys))
        let teenPattern = groupedAlternationPattern(for: Array(spokenTeenValues.keys))
        let tensPattern = groupedAlternationPattern(for: Array(spokenTensValues.keys))
        let separatorPattern = "[\\s-]+"

        return groupedAlternationPattern(
            for: [
                "oh\(separatorPattern)\(unitPattern)",
                teenPattern,
                "\(tensPattern)(?:\(separatorPattern)\(unitPattern))?",
            ]
        )
    }

    private static func groupedAlternationPattern(for tokens: [String]) -> String {
        "(?:\(alternationPattern(for: tokens)))"
    }

    private static func alternationPattern(for tokens: [String]) -> String {
        tokens
            .sorted {
                if $0.count == $1.count {
                    return $0 < $1
                }
                return $0.count > $1.count
            }
            .joined(separator: "|")
    }

    private func normalizedMeridiem(
        _ value: String,
        preservingSentenceBoundaryIn nsText: NSString,
        matchRange: NSRange
    ) -> String {
        let lettersOnly = value
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: #"\s"#, with: "", options: .regularExpression)
        let normalized: String
        if lettersOnly == "am" || lettersOnly == "an" {
            normalized = "AM"
        } else if lettersOnly == "pm" {
            normalized = "PM"
        } else {
            normalized = value
        }

        guard value.hasSuffix("."),
              shouldPreserveSentenceBoundaryPeriod(in: nsText, after: matchRange) else {
            return normalized
        }

        return "\(normalized)."
    }

    private func shouldPreserveSentenceBoundaryPeriod(in nsText: NSString, after matchRange: NSRange) -> Bool {
        let nextIndex = matchRange.location + matchRange.length
        guard nextIndex < nsText.length else { return true }

        let trailingText = nsText.substring(from: nextIndex)
        guard let nextNonWhitespaceScalar = trailingText.unicodeScalars.first(where: {
            !$0.properties.isWhitespace
        }) else {
            return true
        }

        return nextNonWhitespaceScalar.properties.isUppercase
    }
}
