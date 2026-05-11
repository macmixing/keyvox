import Foundation

public struct AsteriskCensorshipArtifactNormalizer {
    private static let censoredLeadingFBeforeKRegex = try? NSRegularExpression(
        pattern: #"(?i)\bf\*\*(?=k)"#,
        options: []
    )

    private static let censoredLeadingFWordRegex = try? NSRegularExpression(
        pattern: #"(?i)\bf\*\*\*(?=$|[^\p{L}\p{N}_])"#,
        options: []
    )

    public init() {}

    public func normalize(in text: String) -> String {
        guard !text.isEmpty else { return text }

        let doubleAsteriskNormalized = replaceMatches(
            using: Self.censoredLeadingFBeforeKRegex,
            in: text
        ) { matchedText in
            replacementPrefix(for: matchedText, lowercasedReplacement: "uc")
        }

        return replaceMatches(
            using: Self.censoredLeadingFWordRegex,
            in: doubleAsteriskNormalized
        ) { matchedText in
            replacementPrefix(for: matchedText, lowercasedReplacement: "uck")
        }
    }

    private func replaceMatches(
        using regex: NSRegularExpression?,
        in text: String,
        replacement: (String) -> String
    ) -> String {
        guard let regex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let matchedText = nsText.substring(with: match.range)
            mutable.replaceCharacters(in: match.range, with: replacement(matchedText))
        }

        return mutable as String
    }

    private func replacementPrefix(for matchedText: String, lowercasedReplacement: String) -> String {
        guard matchedText.first?.isUppercase == true else {
            return "f" + lowercasedReplacement
        }

        return "F" + lowercasedReplacement
    }
}
