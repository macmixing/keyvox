import Foundation

public struct TerminalPeriodNormalizer {
    private let listPatternDetector = ListPatternDetector()
    private let terminalPunctuationNormalizer = TerminalPunctuationNormalizer()

    public init() {}

    public func appendTerminalPeriodIfNeeded(to text: String, languageCode: String? = nil) -> String {
        guard !text.isEmpty else { return text }

        if wordCount(in: text) == 1 {
            return removingTerminalPeriod(from: text)
        }

        guard !terminalPunctuationNormalizer.hasTerminalSentencePunctuation(text),
              !isListOrListItem(text, languageCode: languageCode),
              !isNonProse(text),
              wordCount(in: text) > 1 else {
            return text
        }

        return insertingPeriodBeforeTrailingWhitespace(in: text)
    }

    private func isListOrListItem(_ text: String, languageCode: String?) -> Bool {
        if listPatternDetector.detectList(in: text, languageCode: languageCode) != nil {
            return true
        }

        return text
            .components(separatedBy: .newlines)
            .contains(where: isListItemLine)
    }

    private func isListItemLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        return trimmed.range(
            of: #"^\d+\.\s+\S"#,
            options: .regularExpression
        ) != nil
    }

    private func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func isNonProse(_ text: String) -> Bool {
        MathExpressionNormalizer.isStandaloneMathExpression(text)
            || isNumericOrTimeSequence(text)
            || hasTerminalAddressLine(text)
            || isLaughterSequence(text)
            || hasHeadingSeparator(text)
    }

    private func isNumericOrTimeSequence(_ text: String) -> Bool {
        let withoutMeridiem = text.replacingOccurrences(
            of: #"(?i)\b(?:AM|PM)\b"#,
            with: "",
            options: .regularExpression
        )
        let allowed = CharacterSet(charactersIn: "0123456789.,:-/ ")
        return !withoutMeridiem.isEmpty
            && withoutMeridiem.unicodeScalars.allSatisfy(allowed.contains)
    }

    private func hasTerminalAddressLine(_ text: String) -> Bool {
        guard let terminalLine = text
            .components(separatedBy: .newlines)
            .last(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !terminalLine.contains(where: \.isWhitespace) else {
            return false
        }

        return terminalLine.contains("@") || WebsiteNormalizer.isCompactDomainToken(terminalLine)
    }

    private func isLaughterSequence(_ text: String) -> Bool {
        let tokens = text
            .split(whereSeparator: \.isWhitespace)
            .map { $0.lowercased().filter(\.isLetter) }
        return !tokens.isEmpty && tokens.allSatisfy { $0 == "ha" || $0 == "haha" }
    }

    private func hasHeadingSeparator(_ text: String) -> Bool {
        text.range(of: #"(?<!\d):(?!\d|//)"#, options: .regularExpression) != nil
    }

    private func insertingPeriodBeforeTrailingWhitespace(in text: String) -> String {
        guard let lastNonWhitespace = text.lastIndex(where: { !$0.isWhitespace }) else {
            return text
        }

        let insertionIndex = text.index(after: lastNonWhitespace)
        if text[lastNonWhitespace] == "," {
            return String(text[..<lastNonWhitespace]) + "." + text[insertionIndex...]
        }

        return String(text[..<insertionIndex]) + "." + text[insertionIndex...]
    }

    private func removingTerminalPeriod(from text: String) -> String {
        text.replacingOccurrences(
            of: #"(?<!\.)\.(?!\.)(?=[\"'”’\)\]\}]*\s*$)"#,
            with: "",
            options: .regularExpression
        )
    }
}
