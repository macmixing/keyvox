import Foundation

struct TerminalPunctuationNormalizer {
    private static let terminalTimeRegex = try? NSRegularExpression(
        pattern: #"(?i)\b(?:[1-9]|1[0-2]):[0-5][0-9]\s(?:AM|PM)\s*$"#
    )

    func appendTerminalPeriodIfEndingInFormattedTime(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        // Respect existing terminal punctuation, including punctuation before closing quotes/brackets.
        if text.range(of: #"[.!?…][\"'”’\)\]\}]*\s*$"#, options: .regularExpression) != nil {
            return text
        }

        guard let regex = Self.terminalTimeRegex else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return text
        }

        // Only treat this as sentence-like if there is prose before the terminal time.
        let prefix = nsText.substring(to: match.range.location)
        guard prefix.range(of: #"\b[A-Za-z]{3,}\b"#, options: .regularExpression) != nil else {
            return text
        }

        return text + "."
    }
}
