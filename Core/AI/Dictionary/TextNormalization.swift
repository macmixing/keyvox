import Foundation

enum TextNormalization {
    private static let emailLiteralRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "[A-Z0-9._%+\\-]+@[A-Z0-9.\\-]+\\.[A-Z]{2,}",
        options: [.caseInsensitive]
    )
    private static let punctuationBeforeEmailRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?<![A-Z0-9_%+\\-])([.!?,:;])([A-Z0-9][A-Z0-9._%+\\-]*@[A-Z0-9.\\-]+\\.[A-Z]{2,})",
        options: [.caseInsensitive]
    )
    private static let postEmailSentenceRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "([A-Z0-9._%+\\-]+@[A-Z0-9.\\-]+\\.[A-Z]{2,})([.!?])([a-z])",
        options: [.caseInsensitive]
    )
    private static let spacedEllipsisRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?<!\\.)\\.\\s*\\.\\s*\\.(?!\\.)",
        options: []
    )

    static func normalizedPhrase(_ input: String) -> String {
        let folded = input
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        let lower = folded.lowercased()
        let spaced = lower.replacingOccurrences(of: "[^a-z0-9']+", with: " ", options: .regularExpression)
        return spaced
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func normalizedToken(_ input: String) -> String {
        let phrase = normalizedPhrase(input)
        return phrase.replacingOccurrences(of: " ", with: "")
    }

    static func normalizeEmailAddresses(in input: String) -> String {
        guard !input.isEmpty else { return input }

        var output = input
        output = lowercaseEmailLiterals(in: output)
        output = normalizeSpacingBeforeEmail(in: output)
        output = normalizeSentenceBoundaryAfterEmail(in: output)
        output = normalizeSpacedEllipses(in: output)
        return output
    }

    private static func lowercaseEmailLiterals(in text: String) -> String {
        guard text.contains("@") else { return text }
        guard let regex = emailLiteralRegex else { return text }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let email = nsText.substring(with: match.range).lowercased()
            mutable.replaceCharacters(in: match.range, with: email)
        }

        return mutable as String
    }

    private static func normalizeSpacingBeforeEmail(in text: String) -> String {
        guard let regex = punctuationBeforeEmailRegex else { return text }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let punctuation = nsText.substring(with: match.range(at: 1))
            let email = nsText.substring(with: match.range(at: 2))
            mutable.replaceCharacters(in: match.range, with: "\(punctuation) \(email)")
        }

        return mutable as String
    }

    private static func normalizeSentenceBoundaryAfterEmail(in text: String) -> String {
        guard let regex = postEmailSentenceRegex else { return text }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let email = nsText.substring(with: match.range(at: 1))
            let punctuation = nsText.substring(with: match.range(at: 2))
            let next = nsText.substring(with: match.range(at: 3)).uppercased()
            mutable.replaceCharacters(in: match.range, with: "\(email)\(punctuation) \(next)")
        }

        return mutable as String
    }

    private static func normalizeSpacedEllipses(in text: String) -> String {
        guard let regex = spacedEllipsisRegex else { return text }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: fullRange, withTemplate: "...")
    }
}
