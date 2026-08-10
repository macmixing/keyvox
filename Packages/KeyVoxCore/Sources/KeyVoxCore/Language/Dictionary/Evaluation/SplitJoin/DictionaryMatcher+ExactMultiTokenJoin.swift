import Foundation

extension DictionaryMatcher {
    func proposeExactMultiTokenJoinReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        guard let candidates = entriesByTokenCount[1], !candidates.isEmpty else { return nil }

        for tokenCount in stride(from: 4, through: 3, by: -1) {
            let end = start + tokenCount
            guard end <= tokens.count else { continue }

            let window = Array(tokens[start..<end])
            guard !isLikelyDomainTokenSplit(window: window, text: text) else { continue }

            stats.attempted += 1
            let observedJoined = window.map(\.normalized).joined()
            guard let candidate = candidates.first(where: { $0.normalizedPhrase == observedJoined }) else {
                continue
            }

            let range = combinedRange(from: window)
            let observedRaw = (text as NSString).substring(with: range)
            guard observedRaw != candidate.phrase else { return nil }

            return ProposedReplacement(
                tokenStart: start,
                tokenEndExclusive: end,
                range: range,
                replacement: candidate.phrase,
                score: 1.0
            )
        }

        return nil
    }
}
