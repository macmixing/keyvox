import Foundation

struct TranscriptionLaughterNormalizer {
    private static let laughterRegex = try? NSRegularExpression(
        pattern: #"\bha\s+ha\b"#,
        options: [.caseInsensitive]
    )

    func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let regex = Self.laughterRegex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            mutable.replaceCharacters(in: match.range, with: "haha")
        }
        return mutable as String
    }
}
