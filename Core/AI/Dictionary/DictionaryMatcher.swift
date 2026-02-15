import Foundation

struct DictionaryMatchResult {
    let text: String
    let stats: DictionaryMatcher.DebugStats
}

@MainActor
final class DictionaryMatcher {
    struct DebugStats {
        var attempted: Int = 0
        var accepted: Int = 0
        var rejectedLowScore: Int = 0
        var rejectedAmbiguity: Int = 0
        var rejectedCommonWord: Int = 0
        var rejectedShortToken: Int = 0
        var rejectedOverlap: Int = 0

        static let empty = DebugStats()
    }

    let lexicon: PronunciationLexiconProviding
    let encoder: PhoneticEncoder
    let scorer: ReplacementScorer
    let splitJoinMinimumScore = 0.92
    let minimumSplitTokenLength = 3
    let possessiveStemScoreBoost = 0.06

    var entriesByTokenCount: [Int: [CompiledEntry]] = [:]

    init(
        lexicon: PronunciationLexiconProviding,
        encoder: PhoneticEncoder,
        scorer: ReplacementScorer
    ) {
        self.lexicon = lexicon
        self.encoder = encoder
        self.scorer = scorer
    }

    convenience init() {
        self.init(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
    }

    func rebuildIndex(entries: [DictionaryEntry]) {
        var grouped: [Int: [CompiledEntry]] = [:]

        for entry in entries {
            let normalizedPhrase = TextNormalization.normalizedPhrase(entry.phrase)
            guard !normalizedPhrase.isEmpty else { continue }

            let tokens = normalizedPhrase.split(separator: " ").map(String.init)
            guard !tokens.isEmpty, tokens.count <= 4 else { continue }

            let phoneticPhrase = encoder.phraseSignature(for: tokens, lexicon: lexicon)
            let compiled = CompiledEntry(
                phrase: entry.phrase,
                normalizedPhrase: normalizedPhrase,
                tokens: tokens,
                phoneticPhrase: phoneticPhrase
            )

            grouped[tokens.count, default: []].append(compiled)
        }

        entriesByTokenCount = grouped
    }

    func apply(to text: String) -> DictionaryMatchResult {
        guard !text.isEmpty else {
            return DictionaryMatchResult(text: "", stats: .empty)
        }

        guard !entriesByTokenCount.isEmpty else {
            return DictionaryMatchResult(text: text, stats: .empty)
        }

        let tokens = tokenize(text)
        guard !tokens.isEmpty else {
            return DictionaryMatchResult(text: text, stats: .empty)
        }

        var stats = DebugStats()
        var proposed: [ProposedReplacement] = []

        // Pipeline: propose replacements, resolve overlaps deterministically, then apply right-to-left.
        for start in tokens.indices {
            for tokenCount in 1...4 {
                let end = start + tokenCount
                guard end <= tokens.count else { continue }
                guard let candidates = entriesByTokenCount[tokenCount], !candidates.isEmpty else { continue }

                if let replacement = proposeStandardReplacement(
                    start: start,
                    tokenCount: tokenCount,
                    tokens: tokens,
                    text: text,
                    candidates: candidates,
                    stats: &stats
                ) {
                    proposed.append(replacement)
                }
            }

            if let splitReplacement = proposeSplitJoinReplacement(
                start: start,
                tokens: tokens,
                text: text,
                stats: &stats
            ) {
                proposed.append(splitReplacement)
            }
        }

        guard !proposed.isEmpty else {
            return DictionaryMatchResult(text: text, stats: stats)
        }

        let selected = selectNonOverlapping(proposed: proposed, rejectedOverlapCounter: &stats.rejectedOverlap)
        guard !selected.isEmpty else {
            return DictionaryMatchResult(text: text, stats: stats)
        }

        var output = text
        // Apply from right to left so earlier replacements do not invalidate later NSRanges.
        for item in selected.sorted(by: { $0.range.location > $1.range.location }) {
            guard let swiftRange = Range(item.range, in: output) else { continue }
            output.replaceSubrange(swiftRange, with: item.replacement)
            stats.accepted += 1
        }

        return DictionaryMatchResult(text: output, stats: stats)
    }
}
