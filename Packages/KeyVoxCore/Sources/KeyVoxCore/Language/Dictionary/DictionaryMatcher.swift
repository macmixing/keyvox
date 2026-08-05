import Foundation
import NaturalLanguage

public struct DictionaryMatchResult {
    public let text: String
    public let stats: DictionaryMatcher.DebugStats

    public init(text: String, stats: DictionaryMatcher.DebugStats) {
        self.text = text
        self.stats = stats
    }
}

public final class DictionaryMatcher {
    public struct DebugStats {
        public var attempted: Int = 0
        public var accepted: Int = 0
        public var rejectedLowScore: Int = 0
        public var rejectedAmbiguity: Int = 0
        public var rejectedCommonWord: Int = 0
        public var rejectedShortToken: Int = 0
        public var rejectedOverlap: Int = 0

        public static let empty = DebugStats()

        public init(
            attempted: Int = 0,
            accepted: Int = 0,
            rejectedLowScore: Int = 0,
            rejectedAmbiguity: Int = 0,
            rejectedCommonWord: Int = 0,
            rejectedShortToken: Int = 0,
            rejectedOverlap: Int = 0
        ) {
            self.attempted = attempted
            self.accepted = accepted
            self.rejectedLowScore = rejectedLowScore
            self.rejectedAmbiguity = rejectedAmbiguity
            self.rejectedCommonWord = rejectedCommonWord
            self.rejectedShortToken = rejectedShortToken
            self.rejectedOverlap = rejectedOverlap
        }
    }

    internal let lexicon: PronunciationLexiconProviding
    internal let encoder: PhoneticEncoder
    internal let scorer: ReplacementScorer
    internal let splitJoinMinimumScore = 0.92
    internal let minimumSplitTokenLength = 3
    internal let possessiveStemScoreBoost = 0.06

    internal private(set) var entriesByTokenCount: [Int: [CompiledEntry]] = [:]
    internal private(set) var emailEntriesByDomain: [String: [DictionaryEmailEntry]] = [:]
    
    public init(
        lexicon: PronunciationLexiconProviding,
        encoder: PhoneticEncoder,
        scorer: ReplacementScorer
    ) {
        self.lexicon = lexicon
        self.encoder = encoder
        self.scorer = scorer
    }

    public convenience init() {
        self.init(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
    }

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

    public func rebuildIndex(entries: [DictionaryEntry]) {
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

            for compiled in compiledEntries(
                phrase: entry.phrase,
                normalizedPhrase: normalizedPhrase,
                tokens: tokens
            ) {
                grouped[compiled.tokens.count, default: []].append(compiled)
            }

            for alias in DictionaryBuiltInEntries.aliases(for: entry) {
                let normalizedAlias = DictionaryTextNormalization.normalizedPhrase(alias)
                guard !normalizedAlias.isEmpty, normalizedAlias != normalizedPhrase else { continue }

                let aliasTokens = normalizedAlias.split(separator: " ").map(String.init)
                guard !aliasTokens.isEmpty, aliasTokens.count <= 4 else { continue }

                for compiledAlias in compiledEntries(
                    phrase: entry.phrase,
                    normalizedPhrase: normalizedAlias,
                    tokens: aliasTokens
                ) {
                    grouped[compiledAlias.tokens.count, default: []].append(compiledAlias)
                }
            }
        }

        entriesByTokenCount = grouped
        emailEntriesByDomain = emailGrouped
    }

    private func compiledEntries(
        phrase: String,
        normalizedPhrase: String,
        tokens: [String]
    ) -> [CompiledEntry] {
        var variantsByTokenCount: [Int: [DictionaryNumericMatching.PhraseVariant]] = [:]
        for variant in DictionaryNumericMatching.phraseVariants(for: tokens)
        where !variant.tokens.isEmpty && variant.tokens.count <= 4 {
            variantsByTokenCount[variant.tokens.count, default: []].append(variant)
        }

        return variantsByTokenCount.keys.sorted().compactMap { tokenCount in
            guard let variants = variantsByTokenCount[tokenCount], !variants.isEmpty else {
                return nil
            }

            let activeVariant = variants.first(where: { $0.normalized == normalizedPhrase }) ?? variants[0]
            return CompiledEntry(
                phrase: phrase,
                normalizedPhrase: activeVariant.normalized,
                matchingNormalizedPhrases: variants.map(\.normalized),
                tokens: activeVariant.tokens,
                numericSourceTokens: activeVariant.numericSourceTokens,
                phoneticPhrase: encoder.scoringPhraseSignature(for: activeVariant.tokens, lexicon: lexicon)
            )
        }
    }

    public func apply(to text: String) -> DictionaryMatchResult {
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
        let clauseBoundaryStarts = clauseBoundaryTokenStarts(tokens: tokens)

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

            if let middleInitialReplacement = proposeMiddleInitialThreeTokenReplacement(
                start: start,
                tokens: tokens,
                text: emailNormalizedInput,
                stats: &stats
            ) {
                proposed.append(middleInitialReplacement)
            }

            if let compressedTailReplacement = proposeCompressedTailThreeTokenReplacement(
                start: start,
                tokens: tokens,
                text: emailNormalizedInput,
                stats: &stats
            ) {
                proposed.append(compressedTailReplacement)
            }

            if let exactMultiTokenJoinReplacement = proposeExactMultiTokenJoinReplacement(
                start: start,
                tokens: tokens,
                text: emailNormalizedInput,
                stats: &stats
            ) {
                proposed.append(exactMultiTokenJoinReplacement)
            }

            if let splitReplacement = proposeSplitJoinReplacement(
                start: start,
                tokens: tokens,
                text: emailNormalizedInput,
                stats: &stats
            ) {
                proposed.append(splitReplacement)
            }

            if let mergedTokenReplacement = proposeMergedTokenReplacement(
                start: start,
                tokens: tokens,
                text: emailNormalizedInput,
                stats: &stats
            ) {
                proposed.append(mergedTokenReplacement)
            }
        }

        guard !proposed.isEmpty else {
            return DictionaryMatchResult(text: emailNormalizedInput, stats: stats)
        }

        var selected = selectNonOverlapping(proposed: proposed, rejectedOverlapCounter: &stats.rejectedOverlap)
        if selected.contains(where: \.requiresPeerSupport) {
            let independent = selected.filter { !$0.requiresPeerSupport }
            if independent.isEmpty {
                let rejectedCount = selected.filter(\.requiresPeerSupport).count
                stats.rejectedCommonWord += rejectedCount
                selected.removeAll(where: \.requiresPeerSupport)
            } else {
                let beforeCount = selected.count
                selected.removeAll { candidate in
                    guard candidate.requiresPeerSupport else { return false }
                    return !hasClauseLocalIndependentSupport(
                        for: candidate,
                        independent: independent,
                        clauseBoundaryStarts: clauseBoundaryStarts
                    )
                }
                stats.rejectedCommonWord += (beforeCount - selected.count)
            }
        }
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

    private func hasClauseLocalIndependentSupport(
        for candidate: ProposedReplacement,
        independent: [ProposedReplacement],
        clauseBoundaryStarts: [Int]
    ) -> Bool {
        let clauseIndex = clauseIndexForTokenStart(candidate.tokenStart, clauseBoundaryStarts: clauseBoundaryStarts)
        let minimumSupportTokenCount = 2
        return independent.contains { support in
            clauseIndexForTokenStart(support.tokenStart, clauseBoundaryStarts: clauseBoundaryStarts) == clauseIndex
                && (support.tokenEndExclusive - support.tokenStart) >= minimumSupportTokenCount
        }
    }

    private func clauseBoundaryTokenStarts(tokens: [Token]) -> [Int] {
        guard !tokens.isEmpty else { return [] }

        var boundaries: [Int] = []
        boundaries.reserveCapacity(tokens.count / 4)

        for (index, token) in tokens.enumerated() {
            guard token.lexicalClass == .conjunction else { continue }
            let boundaryStart = index + 1
            if boundaryStart < tokens.count {
                boundaries.append(boundaryStart)
            }
        }

        return boundaries
    }

    private func clauseIndexForTokenStart(_ tokenStart: Int, clauseBoundaryStarts: [Int]) -> Int {
        guard tokenStart > 0 else { return 0 }
        var index = 0
        for boundaryStart in clauseBoundaryStarts {
            if boundaryStart >= tokenStart { break }
            index += 1
        }
        return index
    }
}
