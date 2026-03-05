import Foundation
import NaturalLanguage

enum WebsiteNormalizer {
    static let attachedDomainLookaheadPattern = "(?=[A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)+\\b)"

    private static let compactDomainTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^(?:https?:\/\/)?(?:www\.)?(?:[A-Z0-9\-]+\.)+[A-Z0-9\-]{2,}$"#,
        options: []
    )
    private static let leadingCompactDomainTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^\s*(?:https?:\/\/)?(?:www\.)?(?:[A-Z0-9\-]+\.)+[A-Z0-9\-]{2,}\b"#,
        options: []
    )
    private static let leadingDomainTokenWithPortRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^((?:https?:\/\/)?(?:www\.)?(?:[A-Z0-9\-]+\.)+[A-Z0-9\-]{2,}(?::\d{2,5})?)(.*)$"#,
        options: []
    )
    private static let standaloneWebsiteRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^(?:www\s*\.\s*)?[A-Z0-9\-]+(?:\s*\.\s*[A-Z0-9\-]+)+$"#,
        options: []
    )
    private static let domainTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)(?<![@A-Z0-9._%+\-])((?:https?:\/\/)?(?:www\.)?(?:[A-Z0-9\-]+\.)+[A-Z0-9\-]{2,}(?::\d{2,5})?)(\/[A-Z0-9._~%!$&'()*+,;=:@\/-]*)?"#,
        options: []
    )
    private static let asciiTopLevelDomainRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^[a-z]{2,63}$"#,
        options: []
    )
    private static let punycodeTopLevelDomainRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^xn--[a-z0-9-]{2,59}$"#,
        options: []
    )

    static func isCompactDomainToken(_ text: String) -> Bool {
        guard let regex = compactDomainTokenRegex else { return false }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    static func hasLeadingCompactDomainToken(in text: String) -> Bool {
        guard let regex = leadingCompactDomainTokenRegex else { return false }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    static func normalizeLeadingDomainTokenCasing(in text: String) -> String? {
        guard let regex = leadingDomainTokenWithPortRegex else { return nil }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        let domainRange = match.range(at: 1)
        let suffixRange = match.range(at: 2)
        guard domainRange.location != NSNotFound, suffixRange.location != NSNotFound else { return nil }

        let domain = nsText.substring(with: domainRange).lowercased()
        let suffix = nsText.substring(with: suffixRange)
        return domain + suffix
    }

    static func isStandaloneWebsiteUtterance(_ text: String) -> Bool {
        guard let regex = standaloneWebsiteRegex else { return false }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    static func normalizeDomainCasing(in text: String) -> String {
        guard let regex = domainTokenRegex else { return text }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let domainRange = match.range(at: 1)
            guard domainRange.location != NSNotFound else { continue }

            let rawDomain = nsText.substring(with: domainRange)
            guard shouldNormalizeDomainCasing(rawDomain) else { continue }
            let domain = rawDomain.lowercased()
            let suffix: String
            if match.numberOfRanges > 2 {
                let suffixRange = match.range(at: 2)
                suffix = suffixRange.location == NSNotFound ? "" : nsText.substring(with: suffixRange)
            } else {
                suffix = ""
            }

            mutable.replaceCharacters(in: match.range, with: domain + suffix)
        }

        return mutable as String
    }

    private static func shouldNormalizeDomainCasing(_ rawDomain: String) -> Bool {
        let lowercased = rawDomain.lowercased()
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") || lowercased.hasPrefix("www.") {
            return true
        }

        let hostWithoutPort = lowercased.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? lowercased
        if hasLikelyInitialismPrefixLabels(hostWithoutPort) {
            return false
        }
        guard let tld = hostWithoutPort.split(separator: ".").last.map(String.init), !tld.isEmpty else {
            return false
        }
        return isLikelyTopLevelDomain(tld)
    }

    static func isLikelyTopLevelDomain(_ value: String) -> Bool {
        let tld = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tld.isEmpty else { return false }

        let range = NSRange(location: 0, length: (tld as NSString).length)
        if let asciiRegex = asciiTopLevelDomainRegex,
           asciiRegex.firstMatch(in: tld, options: [], range: range) != nil {
            return true
        }

        if let punycodeRegex = punycodeTopLevelDomainRegex,
           punycodeRegex.firstMatch(in: tld, options: [], range: range) != nil {
            return true
        }

        return false
    }

    static func isLikelySentenceGlueJoin(token: String, in text: NSString, tokenEnd: Int) -> Bool {
        let labels = token.split(separator: ".").map(String.init)
        guard labels.count == 2 else { return false }

        let first = labels[0].lowercased()
        let second = labels[1].lowercased()
        guard first.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil else { return false }
        guard second.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil else { return false }
        guard let following = nextWord(in: text, from: tokenEnd) else { return false }

        let phrase = "\(first) \(second) \(following)"
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = phrase

        var wordIndex = 0
        var middleTag: NLTag?
        tagger.enumerateTags(
            in: phrase.startIndex..<phrase.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, _ in
            if wordIndex == 1 {
                middleTag = tag
                return false
            }
            wordIndex += 1
            return true
        }

        return middleTag == .conjunction
    }

    private static func hasLikelyInitialismPrefixLabels(_ host: String) -> Bool {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count >= 3 else { return false }
        let prefixLabelCount = labels.count - 1
        let singleCharacterPrefixLabels = labels.prefix(prefixLabelCount).filter { $0.count == 1 }.count
        return singleCharacterPrefixLabels >= 2
    }

    private static func nextWord(in text: NSString, from location: Int) -> String? {
        guard location >= 0, location <= text.length else { return nil }
        var index = location
        while index < text.length {
            guard let scalar = UnicodeScalar(text.character(at: index)) else { break }
            if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                break
            }
            index += 1
        }

        guard index < text.length else { return nil }
        let start = index
        while index < text.length {
            guard let scalar = UnicodeScalar(text.character(at: index)),
                  !CharacterSet.whitespacesAndNewlines.contains(scalar) else {
                break
            }
            index += 1
        }

        guard index > start else { return nil }
        let word = text.substring(with: NSRange(location: start, length: index - start))
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}.,;:!?"))
        return word.isEmpty ? nil : word
    }
}
