import Foundation

private struct SpokenLocalCandidate {
    let prefix: String
    let local: String
}

extension DictionaryMatcher {
    private struct StandaloneEmailHint {
        let local: String
        let tld: String?
    }

    func resolveSpokenEmail(localRaw: String, domain: String) -> (prefix: String, entry: DictionaryEmailEntry)? {
        let candidates = spokenLocalCandidates(from: localRaw)
        guard !candidates.isEmpty else { return nil }

        var best: (distance: Int, prefixCount: Int, candidate: SpokenLocalCandidate, entry: DictionaryEmailEntry)?

        for candidate in candidates {
            guard let entry = resolveEntry(local: candidate.local, domain: domain) else { continue }
            let distance = levenshtein(candidate.local, entry.local)
            let prefixCount = candidate.prefix.isEmpty ? 0 : candidate.prefix.split(whereSeparator: { $0.isWhitespace }).count

            if let current = best {
                if distance < current.distance || (distance == current.distance && prefixCount < current.prefixCount) {
                    best = (distance, prefixCount, candidate, entry)
                }
            } else {
                best = (distance, prefixCount, candidate, entry)
            }
        }

        guard let best else { return nil }
        return (best.candidate.prefix, best.entry)
    }

    func resolveLiteralEmail(localRaw: String, localOriginal: String, domain: String) -> (prefix: String, entry: DictionaryEmailEntry)? {
        guard let entries = emailEntriesByDomain[domain], !entries.isEmpty else { return nil }

        if let exact = entries.first(where: { $0.local == localRaw }) {
            return ("", exact)
        }

        let suffixMatches = entries.compactMap { entry -> (prefix: String, entry: DictionaryEmailEntry)? in
            guard localRaw.count > entry.local.count, localRaw.hasSuffix(entry.local) else {
                return nil
            }
            let prefixEnd = localOriginal.index(localOriginal.endIndex, offsetBy: -entry.local.count)
            let prefixRaw = String(localOriginal[..<prefixEnd])
            let prefix = prefixRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefix.isEmpty else { return nil }
            return (prefix, entry)
        }

        if suffixMatches.count == 1, let only = suffixMatches.first {
            return only
        }

        guard let entry = resolveEntry(local: localRaw, domain: domain) else { return nil }
        return ("", entry)
    }

    func resolveStandaloneDictionaryEmail(in raw: String) -> DictionaryEmailEntry? {
        guard let hint = standaloneEmailHint(from: raw) else { return nil }

        var candidates = emailEntriesByDomain.values.flatMap { $0 }
        guard !candidates.isEmpty else { return nil }

        if let tld = hint.tld {
            candidates = candidates.filter { entry in
                guard let entryTLD = entry.domain.split(separator: ".").last else { return false }
                return String(entryTLD) == tld
            }
        }
        guard !candidates.isEmpty else { return nil }

        let maxDistance = hint.local.count >= 8 ? 2 : 1

        let ranked = candidates.map { entry in
            let distance = levenshtein(hint.local, entry.local)
            let lengthDelta = abs(hint.local.count - entry.local.count)
            return (entry: entry, distance: distance, lengthDelta: lengthDelta)
        }
        .sorted {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.lengthDelta != $1.lengthDelta { return $0.lengthDelta < $1.lengthDelta }
            return $0.entry.canonical < $1.entry.canonical
        }

        guard let best = ranked.first, best.distance <= maxDistance else { return nil }
        if ranked.count > 1 {
            let second = ranked[1]
            // Require a clear winner before rewriting a short standalone utterance.
            if second.distance == best.distance {
                return nil
            }
        }

        return best.entry
    }

    func resolveEntry(local: String, domain: String) -> DictionaryEmailEntry? {
        guard let entries = emailEntriesByDomain[domain], !entries.isEmpty else { return nil }

        if let exact = entries.first(where: { $0.local == local }) {
            return exact
        }

        if entries.count == 1, let only = entries.first {
            let distance = levenshtein(local, only.local)
            return distance <= 2 ? only : nil
        }

        let ranked = entries.map { entry in
            (entry: entry, distance: levenshtein(local, entry.local))
        }
        let minDistance = ranked.map { $0.distance }.min() ?? .max
        guard minDistance <= 1 else { return nil }

        let best = ranked.filter { $0.distance == minDistance }
        guard best.count == 1 else { return nil }
        return best[0].entry
    }

    private func spokenLocalCandidates(from raw: String) -> [SpokenLocalCandidate] {
        let originalTokens = raw
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !originalTokens.isEmpty else { return [] }

        let cleanedTokens = originalTokens.map(normalizeLocal).filter { !$0.isEmpty }
        guard !cleanedTokens.isEmpty else { return [] }

        let maxSuffix = cleanedTokens.count
        var results: [SpokenLocalCandidate] = []
        results.reserveCapacity(maxSuffix)

        for suffixCount in 1...maxSuffix {
            let prefixTokens = originalTokens.dropLast(suffixCount)
            let prefix = prefixTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let local = cleanedTokens.suffix(suffixCount).joined()
            guard !local.isEmpty else { continue }
            results.append(SpokenLocalCandidate(prefix: prefix, local: local))
        }

        return results
    }

    private func standaloneEmailHint(from raw: String) -> StandaloneEmailHint? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let regex = try? NSRegularExpression(
            pattern: #"(?i)^\s*([A-Z0-9._%+\-]+)\s*@\s*([A-Z0-9.\-]+\.[A-Z]{2,})\s*$"#,
            options: []
        ) {
            let ns = trimmed as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                let localRaw = ns.substring(with: match.range(at: 1))
                let domainRaw = ns.substring(with: match.range(at: 2))
                if let local = nonEmptyNormalizedLocal(localRaw),
                   let domain = normalizeDomain(domainRaw),
                   let tld = domain.split(separator: ".").last.map(String.init) {
                    return StandaloneEmailHint(local: local, tld: tld)
                }
            }
        }

        if let regex = try? NSRegularExpression(
            pattern: #"(?i)^\s*([A-Z0-9._%+'\-]+(?:\s+[A-Z0-9._%+'\-]+){0,2})\s+at\s+([A-Z0-9.\-\s]+)\s*$"#,
            options: []
        ) {
            let ns = trimmed as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                let localRaw = ns.substring(with: match.range(at: 1))
                let domainRaw = ns.substring(with: match.range(at: 2))
                if let local = nonEmptyNormalizedLocal(localRaw),
                   let domain = normalizeDomain(domainRaw),
                   let tld = domain.split(separator: ".").last.map(String.init) {
                    return StandaloneEmailHint(local: local, tld: tld)
                }
            }
        }

        if let regex = try? NSRegularExpression(
            pattern: #"(?i)^\s*(?:www[\s\.]+)?([A-Z0-9._%+\-]{2,})[\s\.]+([A-Z]{2,})\s*$"#,
            options: []
        ) {
            let ns = trimmed as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                let localRaw = ns.substring(with: match.range(at: 1))
                let tldRaw = ns.substring(with: match.range(at: 2))
                if let local = nonEmptyNormalizedLocal(localRaw) {
                    let tld = tldRaw
                        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                        .lowercased()
                    return StandaloneEmailHint(local: local, tld: tld)
                }
            }
        }

        return nil
    }

    private func nonEmptyNormalizedLocal(_ raw: String) -> String? {
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
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9\\-]+", options: []) else {
            return nil
        }

        let ns = raw as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: raw, options: [], range: range)
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

    func extractAttachedListMarker(from localRaw: String, boundary: String) -> (marker: String, local: String)? {
        guard boundary.isEmpty || boundary.last?.isWhitespace == true || ",;:".contains(boundary) else {
            return nil
        }

        guard let regex = try? NSRegularExpression(
            pattern: "^(\\d{1,2})([\\.\\)\\:\\-])([A-Za-z][A-Za-z0-9._%+'\\-]*(?:[ \\t]+[A-Za-z0-9._%+'\\-]+)*)$",
            options: []
        ) else {
            return nil
        }

        let ns = localRaw as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: localRaw, options: [], range: range) else {
            return nil
        }

        let number = ns.substring(with: match.range(at: 1))
        let delimiter = ns.substring(with: match.range(at: 2))
        let local = ns.substring(with: match.range(at: 3))
        return ("\(number)\(delimiter)", local)
    }

    func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1
            for (j, rhsChar) in rhsChars.enumerated() {
                let substitutionCost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + substitutionCost
                )
            }
            swap(&previous, &current)
        }

        return previous[rhsChars.count]
    }
}
