import Foundation

public struct LaughterNormalizer {
    private static let laughterPairRegex = try? NSRegularExpression(
        pattern: #"\bha\s+ha\b"#,
        options: [.caseInsensitive]
    )
    private static let laughterTripletShorthandRegex = try? NSRegularExpression(
        pattern: #"\bhaha\s+ha\b"#,
        options: [.caseInsensitive]
    )
    private static let laughterSpamRegex = try? NSRegularExpression(
        pattern: #"\bhaha(?:\s+haha){5,}(?:\s+ha)?\b"#,
        options: [.caseInsensitive]
    )
    private static let normalizedLaughterRun = "haha haha haha haha"

    public init() {}

    public func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }

        let pairNormalized = normalizeLaughterPairs(in: text)
        let spamCollapsed = collapseLaughterSpam(in: pairNormalized)
        return expandTripletShorthand(in: spamCollapsed)
    }

    private func normalizeLaughterPairs(in text: String) -> String {
        guard let regex = Self.laughterPairRegex else { return text }

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

    private func expandTripletShorthand(in text: String) -> String {
        guard let regex = Self.laughterTripletShorthandRegex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            mutable.replaceCharacters(in: match.range, with: "ha ha ha")
        }
        return mutable as String
    }

    private func collapseLaughterSpam(in text: String) -> String {
        guard let regex = Self.laughterSpamRegex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            mutable.replaceCharacters(in: match.range, with: Self.normalizedLaughterRun)
        }
        return mutable as String
    }
}
