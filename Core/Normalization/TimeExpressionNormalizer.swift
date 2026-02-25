import Foundation

struct TimeExpressionNormalizer {
    func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }

        let daypartPattern =
            "(?:in the morning|this morning|in the afternoon|this afternoon|in the evening|this evening|at night|tonight)"
        let amMeridiemPattern = "a[\\s\\.-]{0,3}(?:m\\.?|n\\.?)"
        let pmMeridiemPattern = "p[\\s\\.-]{0,3}m\\.?"
        let meridiemPattern = "(?:\(amMeridiemPattern)|\(pmMeridiemPattern))"

        var output = text

        // Normalize spaced/compact meridiem forms while preserving spoken structure.
        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2]):([0-5][0-9])[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            let meridiem = nsText.substring(with: match.range(at: 3))
            return "\(hour):\(minute) \(normalizedMeridiem(meridiem))"
        }

        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2])\s*[\.-]\s*([0-5][0-9])[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            let meridiem = nsText.substring(with: match.range(at: 3))
            return "\(hour):\(minute) \(normalizedMeridiem(meridiem))"
        }

        output = replacingMatches(
            pattern: #"\b([0-9]{3,4})[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let digits = nsText.substring(with: match.range(at: 1))
            guard let formatted = formattedCompactTime(digits) else { return nil }
            let meridiem = nsText.substring(with: match.range(at: 2))
            return "\(formatted) \(normalizedMeridiem(meridiem))"
        }

        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2])[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let meridiem = nsText.substring(with: match.range(at: 2))
            return "\(hour):00 \(normalizedMeridiem(meridiem))"
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

    private func normalizedMeridiem(_ value: String) -> String {
        let lettersOnly = value
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: #"\s"#, with: "", options: .regularExpression)
        if lettersOnly == "am" || lettersOnly == "an" { return "AM" }
        if lettersOnly == "pm" { return "PM" }
        return value
    }
}
