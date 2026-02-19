import Foundation

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
}
