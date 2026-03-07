import Foundation

public enum EmailAddressNormalizer {
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

    public static func normalize(in input: String) -> String {
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
            if punctuation == ".",
               shouldPreserveSecondLevelCountryCodeBoundary(
                   email: email,
                   text: nsText,
                   nextCharacterLocation: match.range(at: 3).location
               ) {
                continue
            }
            let next = nsText.substring(with: match.range(at: 3)).uppercased()
            mutable.replaceCharacters(in: match.range, with: "\(email)\(punctuation) \(next)")
        }

        return mutable as String
    }

    private static func shouldPreserveSecondLevelCountryCodeBoundary(
        email: String,
        text: NSString,
        nextCharacterLocation: Int
    ) -> Bool {
        guard let atIndex = email.lastIndex(of: "@") else { return false }
        let domain = email[email.index(after: atIndex)...]
        let labels = domain.split(separator: ".", omittingEmptySubsequences: true)
        guard let trailingLabel = labels.last, trailingLabel.count == 2 else { return false }

        let followingLabel = contiguousDomainLabel(in: text, from: nextCharacterLocation)
        return followingLabel.count == 2
    }

    private static func contiguousDomainLabel(in text: NSString, from location: Int) -> String {
        guard location >= 0, location < text.length else { return "" }
        var cursor = location
        var scalars: [UnicodeScalar] = []

        while cursor < text.length {
            guard let scalar = UnicodeScalar(text.character(at: cursor)),
                  CharacterSet.alphanumerics.contains(scalar) || scalar == "-" else {
                break
            }
            scalars.append(scalar)
            cursor += 1
        }

        return String(String.UnicodeScalarView(scalars))
    }

    private static func normalizeSpacedEllipses(in text: String) -> String {
        guard let regex = spacedEllipsisRegex else { return text }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: fullRange, withTemplate: "...")
    }
}
