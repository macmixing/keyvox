import Foundation

public struct DictionaryEmailEntry {
    public let canonical: String
    public let local: String
    public let domain: String

    private static let literalRegex = try? NSRegularExpression(
        pattern: "^([A-Z0-9._%+\\-]+)@([A-Z0-9.\\-]+\\.[A-Z]{2,})$",
        options: [.caseInsensitive]
    )

    public static func fromPhrase(_ phrase: String) -> DictionaryEmailEntry? {
        let cleaned = sanitizeEmailCandidate(phrase)
        guard !cleaned.isEmpty, let regex = literalRegex else { return nil }

        let ns = cleaned as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: cleaned, options: [], range: fullRange) else {
            return nil
        }

        let localRaw = ns.substring(with: match.range(at: 1))
        let domainRaw = ns.substring(with: match.range(at: 2))
        guard let canonical = canonicalEmail(local: localRaw, domain: domainRaw) else {
            return nil
        }

        let parts = canonical.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        return DictionaryEmailEntry(
            canonical: canonical,
            local: String(parts[0]),
            domain: String(parts[1])
        )
    }

    private static func sanitizeEmailCandidate(_ phrase: String) -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let punctuation = CharacterSet(charactersIn: "\"'“”‘’()[]{}<>,;:.!?")
        return trimmed.trimmingCharacters(in: punctuation)
    }

    private static func canonicalEmail(local: String, domain: String) -> String? {
        let localNormalized = local
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9._%+\\-]", with: "", options: .regularExpression)

        var domainNormalized = domain
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9.\\-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.{2,}", with: ".", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))

        let labels = domainNormalized
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
            .filter { !$0.isEmpty }
        domainNormalized = labels.joined(separator: ".")

        guard !localNormalized.isEmpty else { return nil }
        guard labels.count >= 2 else { return nil }
        guard let tld = labels.last,
              tld.range(of: "^[a-z]{2,}$", options: .regularExpression) != nil else {
            return nil
        }

        return "\(localNormalized)@\(domainNormalized)"
    }
}
