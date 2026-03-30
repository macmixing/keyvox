import Foundation

extension DictionaryMatcher {
    private static let domainLabelRegex = try! NSRegularExpression(
        pattern: "[A-Za-z0-9\\-]+",
        options: []
    )
    private static let spokenDotRegex = try! NSRegularExpression(
        pattern: #"(?i)\bdot\b"#,
        options: []
    )

    func resolveDictionaryDomainCandidate(_ raw: String, localHint: String? = nil) -> (domain: String, overflow: String)? {
        guard let labelBundle = extractDomainLabels(from: raw) else { return nil }
        let normalizedLabels = labelBundle.normalized
        let rawLabels = labelBundle.raw
        let normalized = normalizedLabels.joined(separator: ".")

        if emailEntriesByDomain[normalized] != nil {
            return (normalized, "")
        }
        if let fuzzyDomain = resolveFuzzyDomainCandidate(normalized, localHint: localHint) {
            return (fuzzyDomain, "")
        }

        guard normalizedLabels.count >= 3 else { return nil }

        for endIndexExclusive in stride(from: normalizedLabels.count - 1, through: 2, by: -1) {
            let candidateDomain = normalizedLabels[..<endIndexExclusive].joined(separator: ".")
            if emailEntriesByDomain[candidateDomain] != nil {
                let overflow = rawLabels[endIndexExclusive...].joined(separator: " ")
                return (candidateDomain, overflow)
            }
            guard let fuzzyDomain = resolveFuzzyDomainCandidate(candidateDomain, localHint: localHint) else { continue }

            let overflow = rawLabels[endIndexExclusive...].joined(separator: " ")
            return (fuzzyDomain, overflow)
        }

        return nil
    }

    private func extractDomainLabels(from raw: String) -> (normalized: [String], raw: [String])? {
        let normalizedSeparators = Self.spokenDotRegex.stringByReplacingMatches(
            in: raw,
            options: [],
            range: NSRange(location: 0, length: (raw as NSString).length),
            withTemplate: "."
        )

        let ns = normalizedSeparators as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = Self.domainLabelRegex.matches(in: normalizedSeparators, options: [], range: range)
        guard !matches.isEmpty else { return nil }

        var rawLabels: [String] = []
        var normalizedLabels: [String] = []
        rawLabels.reserveCapacity(matches.count)
        normalizedLabels.reserveCapacity(matches.count)

        for match in matches {
            let token = ns.substring(with: match.range)
            let trimmedRaw = token.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            guard !trimmedRaw.isEmpty else { continue }

            let normalized = trimmedRaw
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            guard !normalized.isEmpty else { continue }

            rawLabels.append(trimmedRaw)
            normalizedLabels.append(normalized)
        }

        guard normalizedLabels.count >= 2 else { return nil }
        guard let tld = normalizedLabels.last,
              tld.range(of: "^[a-z]{2,}$", options: .regularExpression) != nil else {
            return nil
        }

        return (normalizedLabels, rawLabels)
    }

    private func resolveFuzzyDomainCandidate(_ candidateDomain: String, localHint: String?) -> String? {
        let candidateLabels = candidateDomain.split(separator: ".").map(String.init)
        guard candidateLabels.count >= 2 else { return nil }

        let candidateHost = candidateLabels.dropLast().joined(separator: ".")
        guard !candidateHost.isEmpty else { return nil }

        guard let candidateTLD = candidateLabels.last else { return nil }

        let maxDistance = candidateHost.count >= 6 ? 2 : 1

        let normalizedLocalHint = localHint.map(normalizeLocal).flatMap { $0.isEmpty ? nil : $0 }
        let candidateSignature = hostPhoneticSignature(candidateHost)

        let ranked = emailEntriesByDomain.keys.compactMap {
            knownDomain -> (domain: String, distance: Int, lengthDelta: Int, localDistance: Int, firstLetterMatch: Bool)? in
            let knownLabels = knownDomain.split(separator: ".").map(String.init)
            guard knownLabels.count == candidateLabels.count else { return nil }
            guard knownLabels.last == candidateTLD else { return nil }

            let knownHost = knownLabels.dropLast().joined(separator: ".")
            guard !knownHost.isEmpty else { return nil }

            let lengthDelta = abs(candidateHost.count - knownHost.count)
            guard lengthDelta <= 2 else { return nil }

            let distance = levenshtein(candidateHost, knownHost)
            guard distance <= maxDistance else { return nil }

            let firstLetterMatch = candidateHost.first == knownHost.first
            let localDistance = bestLocalDistance(for: normalizedLocalHint, in: knownDomain) ?? .max

            if !firstLetterMatch {
                let knownSignature = hostPhoneticSignature(knownHost)
                guard !candidateSignature.isEmpty,
                      candidateSignature == knownSignature else {
                    return nil
                }
                // Require strong local-part evidence before crossing first-letter domain boundaries.
                guard localDistance <= 1 else { return nil }
            }

            return (knownDomain, distance, lengthDelta, localDistance, firstLetterMatch)
        }
        .sorted {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.localDistance != $1.localDistance { return $0.localDistance < $1.localDistance }
            if $0.lengthDelta != $1.lengthDelta { return $0.lengthDelta < $1.lengthDelta }
            return $0.domain < $1.domain
        }

        guard let best = ranked.first else { return nil }
        if ranked.count > 1 {
            let next = ranked[1]
            if next.distance == best.distance &&
                next.localDistance == best.localDistance &&
                next.lengthDelta == best.lengthDelta {
                return nil
            }
        }

        return best.domain
    }

    private func bestLocalDistance(for normalizedLocal: String?, in domain: String) -> Int? {
        guard let normalizedLocal,
              let entries = emailEntriesByDomain[domain],
              !entries.isEmpty else {
            return nil
        }

        return entries.map { levenshtein(normalizedLocal, $0.local) }.min()
    }

    private func hostPhoneticSignature(_ host: String) -> String {
        let flattened = host.replacingOccurrences(of: ".", with: "")
        guard !flattened.isEmpty else { return "" }
        return encoder.signature(for: flattened, lexicon: lexicon)
    }
}
