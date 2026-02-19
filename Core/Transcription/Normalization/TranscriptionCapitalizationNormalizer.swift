import Foundation

struct TranscriptionCapitalizationNormalizer {
    private static let domainLikeTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^(?:https?://)?(?:www\.)?[a-z0-9\-]+(?:\.[a-z0-9\-]+)+/?$"#,
        options: []
    )
    private static let commonTopLevelDomains: Set<String> = [
        "com", "net", "org", "io", "app", "dev", "ai", "co", "me", "edu", "gov",
        "us", "uk", "ca", "au", "de", "fr", "jp"
    ]
    private static let domainLabelCharacterSet = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-"
    )

    func normalizeSentenceStarts(in text: String) -> String {
        let textStartNormalized = capitalizeAtTextStart(text)
        let sentenceStartNormalized = capitalizeAfterSentenceBoundary(textStartNormalized)
        return capitalizeAfterLineBreak(sentenceStartNormalized)
    }

    private func capitalizeAtTextStart(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\s*["'“”‘’\(\[\{]*)([a-z])"#,
            options: []
        ) else {
            return text
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return text }
        if isAddressOrURLToken(firstToken(in: text)) { return text }

        let prefix = nsText.substring(with: match.range(at: 1))
        let nextLetter = nsText.substring(with: match.range(at: 2)).uppercased()
        let mutable = NSMutableString(string: text)
        mutable.replaceCharacters(in: match.range, with: "\(prefix)\(nextLetter)")
        return mutable as String
    }

    private func capitalizeAfterSentenceBoundary(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let boundaryRegex = try? NSRegularExpression(
            pattern: #"(?<!\d)([.!?;:…]["'”’\)\]\}]*)(\s*)([a-z])"#,
            options: []
        ) else {
            return text
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = boundaryRegex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let tokenStart = match.range(at: 3).location
            let tokenTail = nsText.substring(with: NSRange(location: tokenStart, length: nsText.length - tokenStart))
            let firstToken = tokenTail.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            if isAddressOrURLToken(firstToken) {
                continue
            }

            let boundaryText = nsText.substring(with: match.range(at: 1))
            if boundaryText.first == "." {
                if isLikelyDomainBoundary(text, dotLocation: match.range(at: 1).location) {
                    continue
                }

                let prefixText = nsText.substring(to: match.range(at: 1).location)
                let previousToken = prefixText.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
                if previousToken.contains("@") {
                    continue
                }
            }

            let prefix = nsText.substring(with: match.range(at: 1))
            let spacing = nsText.substring(with: match.range(at: 2))
            let separator = spacing.isEmpty ? " " : spacing
            let nextLetter = nsText.substring(with: match.range(at: 3)).uppercased()
            mutable.replaceCharacters(in: match.range, with: "\(prefix)\(separator)\(nextLetter)")
        }

        return mutable as String
    }

    private func capitalizeAfterLineBreak(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let lineBreakRegex = try? NSRegularExpression(
            pattern: #"(\n)([ \t]*["'“”‘’\(\[\{]*)([a-z])"#,
            options: []
        ) else {
            return text
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = lineBreakRegex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let tokenStart = match.range(at: 3).location
            guard !lineStartsWithAddressOrURL(in: nsText, from: tokenStart) else { continue }
            let newline = nsText.substring(with: match.range(at: 1))
            let prefix = nsText.substring(with: match.range(at: 2))
            let nextLetter = nsText.substring(with: match.range(at: 3)).uppercased()
            mutable.replaceCharacters(in: match.range, with: "\(newline)\(prefix)\(nextLetter)")
        }

        return mutable as String
    }

    private func lineStartsWithAddressOrURL(in text: NSString, from location: Int) -> Bool {
        guard location >= 0, location < text.length else { return false }
        let suffix = text.substring(with: NSRange(location: location, length: text.length - location))
        let line = suffix.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let firstToken = firstToken(in: line)
        guard !firstToken.isEmpty else { return false }
        return isAddressOrURLToken(firstToken)
    }

    private func isAddressOrURLToken(_ token: String) -> Bool {
        let stripped = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}.,;:!?"))
        guard !stripped.isEmpty else { return false }

        let lowered = stripped.lowercased()
        if lowered.contains("@") {
            let parts = lowered.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") {
                return true
            }
        }

        var candidate = lowered
        if candidate.hasPrefix("http://") {
            candidate.removeFirst("http://".count)
        } else if candidate.hasPrefix("https://") {
            candidate.removeFirst("https://".count)
        }
        if let hostOnly = candidate.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first {
            candidate = String(hostOnly)
        }

        let range = NSRange(location: 0, length: (candidate as NSString).length)
        if let domainRegex = Self.domainLikeTokenRegex,
           domainRegex.firstMatch(in: candidate, options: [], range: range) != nil {
            return true
        }
        return false
    }

    private func firstToken(in text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init) ?? ""
    }

    private func isLikelyDomainBoundary(_ text: String, dotLocation: Int) -> Bool {
        guard dotLocation >= 0 else { return false }
        let nsText = text as NSString
        guard dotLocation < nsText.length else { return false }
        guard dotLocation + 1 < nsText.length else { return false }

        guard let nextScalar = UnicodeScalar(nsText.character(at: dotLocation + 1)),
              Self.domainLabelCharacterSet.contains(nextScalar) else {
            return false
        }

        var start = dotLocation
        while start > 0 {
            guard let scalar = UnicodeScalar(nsText.character(at: start - 1)) else { break }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                break
            }
            start -= 1
        }

        var end = dotLocation + 1
        while end < nsText.length {
            guard let scalar = UnicodeScalar(nsText.character(at: end)) else { break }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                break
            }
            end += 1
        }

        let tokenRange = NSRange(location: start, length: end - start)
        guard tokenRange.length > 0 else { return false }

        let token = nsText.substring(with: tokenRange)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}"))
            .replacingOccurrences(
                of: #"[.,;:!?]+$"#,
                with: "",
                options: .regularExpression
            )
        guard !token.isEmpty, !token.contains("@"), token.contains(".") else { return false }

        guard let regex = Self.domainLikeTokenRegex else { return false }
        let fullRange = NSRange(location: 0, length: (token as NSString).length)
        guard regex.firstMatch(in: token, options: [], range: fullRange) != nil else { return false }

        let normalized = token.lowercased()
        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") || normalized.hasPrefix("www.") {
            return true
        }

        let dotCount = normalized.filter { $0 == "." }.count
        if dotCount >= 2 {
            return true
        }

        guard let tld = normalized.split(separator: ".").last.map(String.init) else { return false }
        return Self.commonTopLevelDomains.contains(tld)
    }
}
