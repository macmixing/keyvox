import Foundation

extension DictionaryMatcher {
    private static let attachedListMarkerRegex = try! NSRegularExpression(
        pattern: "^(\\d{1,2})([\\.\\)\\:\\-])([A-Za-z][A-Za-z0-9._%+'\\-]*(?:[ \\t]+[A-Za-z0-9._%+'\\-]+)*)$",
        options: []
    )

    func nonEmptyNormalizedLocal(_ raw: String) -> String? {
        let normalized = normalizeLocal(raw)
        return normalized.isEmpty ? nil : normalized
    }

    func normalizeLocal(_ raw: String) -> String {
        raw
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9._%+\\-]", with: "", options: .regularExpression)
    }

    func normalizeDomain(_ raw: String) -> String? {
        var normalized = raw
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9.\\-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.{2,}", with: ".", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))

        let labels = normalized
            .split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
            .filter { !$0.isEmpty }
        normalized = labels.joined(separator: ".")

        guard labels.count >= 2 else { return nil }
        guard let tld = labels.last,
              tld.range(of: "^[a-z]{2,}$", options: .regularExpression) != nil else {
            return nil
        }

        return normalized
    }

    func extractAttachedListMarker(from localRaw: String, boundary: String) -> (marker: String, local: String)? {
        guard boundary.isEmpty || boundary.last?.isWhitespace == true || ",;:".contains(boundary) else {
            return nil
        }

        let ns = localRaw as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = Self.attachedListMarkerRegex.firstMatch(in: localRaw, options: [], range: range) else {
            return nil
        }

        let number = ns.substring(with: match.range(at: 1))
        let delimiter = ns.substring(with: match.range(at: 2))
        let local = ns.substring(with: match.range(at: 3))
        return ("\(number)\(delimiter)", local)
    }
}
