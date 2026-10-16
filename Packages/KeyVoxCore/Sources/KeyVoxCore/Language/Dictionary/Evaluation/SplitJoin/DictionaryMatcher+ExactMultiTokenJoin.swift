import Foundation

extension DictionaryMatcher {
    func proposeExactMultiTokenJoinReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        for tokenCount in stride(from: 4, through: 3, by: -1) {
            let end = start + tokenCount
            guard end <= tokens.count else { continue }

            let window = Array(tokens[start..<end])
            guard !isLikelyDomainTokenSplit(window: window, text: text) else { continue }

            stats.attempted += 1
            guard let candidate = exactSplitJoinCandidate(for: window) else {
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

    /// Finds an entry with fewer tokens than the window whose every token is spelled
    /// exactly by consecutive window tokens, so only split words are rejoined.
    private func exactSplitJoinCandidate(for window: [Token]) -> CompiledEntry? {
        for entryTokenCount in 1..<window.count {
            guard let candidates = entriesByTokenCount[entryTokenCount] else { continue }
            if let candidate = candidates.first(where: { isExactSplit(of: $0.tokens, in: window) }) {
                return candidate
            }
        }
        return nil
    }

    private func isExactSplit(of entryTokens: [String], in window: [Token]) -> Bool {
        var windowIndex = 0
        for entryToken in entryTokens {
            var joined = ""
            while windowIndex < window.count, joined.count < entryToken.count {
                joined += window[windowIndex].normalized
                windowIndex += 1
            }
            guard joined == entryToken else { return false }
        }
        return windowIndex == window.count
    }
}
