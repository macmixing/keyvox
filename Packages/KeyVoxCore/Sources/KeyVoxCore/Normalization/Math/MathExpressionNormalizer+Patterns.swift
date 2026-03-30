import Foundation

extension MathExpressionNormalizer {
    struct WordToken {
        let range: NSRange
        let text: String

        var normalized: String {
            text.lowercased()
        }
    }

    static let operatorWordToSymbol: [String: String] = [
        "plus": "+",
        "minus": "-",
        "subtract": "-",
        "subtracted by": "-",
        "times": "*",
        "multiplied by": "*",
        "divided by": "/"
    ]

    static let operatorWordAlternation: String = {
        operatorWordToSymbol.keys
            .sorted { $0.count > $1.count }
            .map { key in
                NSRegularExpression.escapedPattern(for: key)
                    .replacingOccurrences(of: " ", with: #"\s+"#)
            }
            .joined(separator: "|")
    }()

    static let spellOutNumberParser: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .spellOut
        return formatter
    }()

    static let wordTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b[\p{L}]+(?:-[\p{L}]+)*\b"#,
        options: []
    )

    static let binaryOperatorTokenPhrases: [[String]] = operatorWordToSymbol.keys
        .map { $0.split(separator: " ").map(String.init) }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.joined(separator: " ").count > rhs.joined(separator: " ").count
        }

    static let equalsTokenPhrase = ["equals"]
    static let squaredTokenPhrase = ["squared"]
    static let cubedTokenPhrase = ["cubed"]
    static let percentTokenPhrase = ["percent"]
    static let toThePowerOfTokenPhrase = ["to", "the", "power", "of"]
    static let powerOfTokenPhrase = ["power", "of"]
    static let raisedToTokenPhrase = ["raised", "to"]

    static let standaloneMathAllowedCharsRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^[\s0-9().+\-*/^=%]+$"#,
        options: []
    )
    static let standaloneMathOperatorRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[+\-*/^=%]"#,
        options: []
    )
    static let maxChainedOperatorPasses = 4

    static let protectedEmailRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )
    static let protectedURLRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:https?:\/\/|www\.)[^\s]+"#,
        options: []
    )
    static let protectedDomainRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[A-Z0-9\-]+\.)+[A-Z]{2,}(?:\/[^\s]*)?"#,
        options: []
    )
    static let protectedTimeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b\d{1,2}:\d{2}(?:\s?[AP]M)?\b"#,
        options: []
    )
    static let protectedMalformedTimeWithMeridiemRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[1-9]|1[0-2])\s*[.-]\s*[0-5][0-9](?:[\s-]*(?:a[\s.-]*m\.?|a[\s.-]*n\.?|p[\s.-]*m\.?))\b"#,
        options: []
    )
    static let protectedMalformedTimeWithDaypartRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[1-9]|1[0-2])[.-][0-5][0-9](?=\s+(?:in the morning|this morning|in the afternoon|this afternoon|in the evening|this evening|at night|tonight)\b)"#,
        options: []
    )
    static let protectedDateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{4}-\d{2}-\d{2}\b"#,
        options: []
    )
    static let protectedVersionRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d+(?:\.\d+){2,}\b"#,
        options: []
    )
    static let protectedPhoneRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:\d{3}\s*-\s*)?\d{3}\s*-\s*\d{4}\b"#,
        options: []
    )
    static let protectedCompactHyphenatedNumericRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d{1,4}(?:-\d{1,4}){2,}\b"#,
        options: []
    )

    static let mathTriggerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?i)\\b(?:\(operatorWordAlternation)|equals|percent|squared|cubed|power\\s+of|to\\s+the\\s+power\\s+of|to\\s+the\\s+[A-Z0-9\\-.]+(?:\\s+[A-Z0-9\\-.]+)*\\s+power|raised\\s+to)\\b|(?<=\\d)\\s*-\\s*(?=\\d)",
        options: []
    )
    static let toThePowerOfRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+to\s+the\s+power\s+of\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    static let toTheOrdinalPowerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+to\s+the\s+([A-Z0-9.\-]+(?:\s+[A-Z0-9.\-]+)*)\s+power\b"#,
        options: []
    )
    static let raisedToRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+raised\s+to\s+(?:the\s+)?([A-Z0-9.\-]+(?:\s+[A-Z0-9.\-]+)*)(?:\s+power)?\b"#,
        options: []
    )
    static let powerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+power\s+of\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    static let squaredRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+squared\b"#,
        options: []
    )
    static let cubedRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+cubed\b"#,
        options: []
    )
    static let percentRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?)\s+percent\b"#,
        options: []
    )
    static let multiplicationByXRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<=\d)\s*[x×]\s*(?=\d)"#,
        options: [.caseInsensitive]
    )
    static let binaryOperatorRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?i)\\b(\\d+(?:\\.\\d+)?)\\s+(\(operatorWordAlternation))\\s+(\\d+(?:\\.\\d+)?)\\b",
        options: []
    )
    static let expressionOperatorRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?i)\\b((?:\\d|\\()[0-9().+\\-*/^%\\s]*?\\d)\\s*,?\\s*(\(operatorWordAlternation))\\s+(\\d+(?:\\.\\d+)?)\\b",
        options: []
    )
    static let equalsRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+(?:\.\d+)?(?:\s*(?:\^|[+\-*/])\s*\d+(?:\.\d+)?)*)\s+equals\s+(\d+(?:\.\d+)?)\b"#,
        options: []
    )
    static let subtractionSymbolRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<=\d)\s*-\s*(?=\d)"#,
        options: []
    )
    static let binarySymbolSpacingRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s*([+\-*/=])\s*"#,
        options: []
    )
    static let exponentTighteningRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s*\^\s*"#,
        options: []
    )
    static let whitespaceCollapseRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s{2,}"#,
        options: []
    )
    static let trailingTerminalPunctuationRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[.!?]+\s*$"#,
        options: []
    )
    static let numericOrdinalExponentRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^(\d+)(?:st|nd|rd|th)?$"#,
        options: []
    )
}
