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
    private static let standaloneLiteralEmailHintRegex = try! NSRegularExpression(
        pattern: #"(?i)^\s*([A-Z0-9._%+\-]+)\s*@\s*([A-Z0-9.\-]+\.[A-Z]{2,})\s*$"#,
        options: []
    )
    private static let standaloneSpokenEmailHintRegex = try! NSRegularExpression(
        pattern: #"(?i)^\s*([A-Z0-9._%+'\-]+(?:\s+[A-Z0-9._%+'\-]+){0,2})\s+at\s+([A-Z0-9.\-\s]+)\s*$"#,
        options: []
    )
    private static let standaloneWebsiteHintRegex = try! NSRegularExpression(
        pattern: #"(?i)^\s*(?:www[\s\.]+)?([A-Z0-9._%+\-]{2,})[\s\.]+([A-Z]{2,})\s*$"#,
        options: []
    )

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

        let ns = trimmed as NSString
        let range = NSRange(location: 0, length: ns.length)

        if let match = Self.standaloneLiteralEmailHintRegex.firstMatch(in: trimmed, options: [], range: range) {
            let localRaw = ns.substring(with: match.range(at: 1))
            let domainRaw = ns.substring(with: match.range(at: 2))
            if let local = nonEmptyNormalizedLocal(localRaw),
               let domain = normalizeDomain(domainRaw),
               let tld = domain.split(separator: ".").last.map(String.init) {
                return StandaloneEmailHint(local: local, tld: tld)
            }
        }

        if let match = Self.standaloneSpokenEmailHintRegex.firstMatch(in: trimmed, options: [], range: range) {
            let localRaw = ns.substring(with: match.range(at: 1))
            let domainRaw = ns.substring(with: match.range(at: 2))
            if let local = nonEmptyNormalizedLocal(localRaw),
               let domain = normalizeDomain(domainRaw),
               let tld = domain.split(separator: ".").last.map(String.init) {
                return StandaloneEmailHint(local: local, tld: tld)
            }
        }

        if let match = Self.standaloneWebsiteHintRegex.firstMatch(in: trimmed, options: [], range: range) {
            let localRaw = ns.substring(with: match.range(at: 1))
            let tldRaw = ns.substring(with: match.range(at: 2))
            if let local = nonEmptyNormalizedLocal(localRaw) {
                let tld = tldRaw
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
                return StandaloneEmailHint(local: local, tld: tld)
            }
        }

        return nil
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
