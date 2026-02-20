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
    var emailEntriesByDomain: [String: [DictionaryEmailEntry]] = [:]

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

    // Keep teardown executor-agnostic to avoid runtime deinit crashes in test host.
    nonisolated deinit {}

    func rebuildIndex(entries: [DictionaryEntry]) {
        var grouped: [Int: [CompiledEntry]] = [:]
        var emailGrouped: [String: [DictionaryEmailEntry]] = [:]

        for entry in entries {
            if let emailEntry = DictionaryEmailEntry.fromPhrase(entry.phrase) {
                emailGrouped[emailEntry.domain, default: []].append(emailEntry)
                // Canonical email phrases should participate in email resolution only.
                // Indexing them as generic dictionary phrases can incorrectly rewrite
                // domain tokens (e.g. websites) into email addresses.
                continue
            }

            let normalizedPhrase = DictionaryTextNormalization.normalizedPhrase(entry.phrase)
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
        emailEntriesByDomain = emailGrouped
    }

    func apply(to text: String) -> DictionaryMatchResult {
        guard !text.isEmpty else {
            return DictionaryMatchResult(text: "", stats: .empty)
        }

        let dictionaryEmailNormalizedInput = normalizeEmailsUsingDictionary(in: text)
        let emailNormalizedInput = EmailAddressNormalizer.normalize(in: dictionaryEmailNormalizedInput)

        guard !entriesByTokenCount.isEmpty else {
            return DictionaryMatchResult(text: emailNormalizedInput, stats: .empty)
        }

        let tokens = tokenize(emailNormalizedInput)
        guard !tokens.isEmpty else {
            return DictionaryMatchResult(text: emailNormalizedInput, stats: .empty)
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
                    text: emailNormalizedInput,
                    candidates: candidates,
                    stats: &stats
                ) {
                    proposed.append(replacement)
                }
            }

            if let splitReplacement = proposeSplitJoinReplacement(
                start: start,
                tokens: tokens,
                text: emailNormalizedInput,
                stats: &stats
            ) {
                proposed.append(splitReplacement)
            }
        }

        guard !proposed.isEmpty else {
            return DictionaryMatchResult(text: emailNormalizedInput, stats: stats)
        }

        let selected = selectNonOverlapping(proposed: proposed, rejectedOverlapCounter: &stats.rejectedOverlap)
        guard !selected.isEmpty else {
            return DictionaryMatchResult(text: emailNormalizedInput, stats: stats)
        }

        var output = emailNormalizedInput
        // Apply from right to left so earlier replacements do not invalidate later NSRanges.
        for item in selected.sorted(by: { $0.range.location > $1.range.location }) {
            guard let swiftRange = Range(item.range, in: output) else { continue }
            output.replaceSubrange(swiftRange, with: item.replacement)
            stats.accepted += 1
        }

        return DictionaryMatchResult(text: output, stats: stats)
    }
}
