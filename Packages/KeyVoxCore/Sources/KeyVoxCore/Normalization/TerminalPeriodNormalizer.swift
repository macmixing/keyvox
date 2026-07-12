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

    private func insertingPeriodBeforeTrailingWhitespace(in text: String) -> String {
        guard let lastNonWhitespace = text.lastIndex(where: { !$0.isWhitespace }) else {
            return text
        }

        let insertionIndex = text.index(after: lastNonWhitespace)
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
