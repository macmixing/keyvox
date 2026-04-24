import Foundation

private enum EvaluationStylizedConstants {
    static let minimumObservedLength = 4
    static let minimumCandidateLength = 5

    static let strongTextEvidenceMinimum = 0.83
    static let strongFallbackTextMinimum = 0.22
    static let strongFallbackSimilarityMinimum = 0.88
    static let moderateFallbackTextMinimum = 0.42
    static let moderateFallbackSimilarityMinimum = 0.66
    static let longPrefixTailGuardMinimumSharedPrefixLength = 4
    static let longPrefixTailGuardMinimumSimilarity = 0.55
}

extension DictionaryMatcher {
    func isTitlecaseToken(_ token: Token) -> Bool {
        guard let first = token.raw.unicodeScalars.first,
              first.properties.isUppercase else {
            return false
        }

        return token.raw.unicodeScalars.dropFirst().contains { $0.properties.isLowercase }
    }

    func hasAdjacentTitlecasePhraseContext(
        tokenIndex: Int,
        totalTokens: Int,
        tokens: [Token],
        text: String
    ) -> Bool {
        guard tokens[tokenIndex].normalized.count >= 3,
              isTitlecaseToken(tokens[tokenIndex]) else {
            return false
        }

        let previousIsTitlecase =
            tokenIndex > 0
            && tokens[tokenIndex - 1].normalized.count >= 3
            && isTitlecaseToken(tokens[tokenIndex - 1])
            && !hasSentenceBoundaryBetween(tokens[tokenIndex - 1], tokens[tokenIndex], in: text)
        let nextIsTitlecase =
            tokenIndex + 1 < totalTokens
            && tokens[tokenIndex + 1].normalized.count >= 3
            && isTitlecaseToken(tokens[tokenIndex + 1])
            && !hasSentenceBoundaryBetween(tokens[tokenIndex], tokens[tokenIndex + 1], in: text)

        return previousIsTitlecase || nextIsTitlecase
    }

    private func hasSentenceBoundaryBetween(_ left: Token, _ right: Token, in text: String) -> Bool {
        let leftEnd = left.range.location + left.range.length
        let rightStart = right.range.location
        guard rightStart > leftEnd else { return false }

        let bridge = text as NSString
        let gap = bridge.substring(with: NSRange(location: leftEnd, length: rightStart - leftEnd))
        return gap.contains(".") || gap.contains("?") || gap.contains("!") || gap.contains("\n")
    }

    func isStylizedSingleTokenEntry(_ entry: CompiledEntry) -> Bool {
        guard entry.tokens.count == 1 else { return false }
        guard !entry.phrase.contains(" ") else { return false }
        let firstScalar = entry.phrase.unicodeScalars.first
        return entry.phrase.unicodeScalars.contains { scalar in
            guard scalar.properties.isUppercase else { return false }
            return scalar != firstScalar
        }
    }

    func hasStrongStylizedTextEvidence(
        observed: String,
        candidate: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= EvaluationStylizedConstants.strongTextEvidenceMinimum else { return false }
        guard observed.unicodeScalars.first == candidate.unicodeScalars.first else { return false }
        guard observed.unicodeScalars.last == candidate.unicodeScalars.last else { return false }
        return true
    }

    func stylizedFallbackPhoneticSimilarity(
        tokenCount: Int,
        observedNormalized: String,
        observedPhonetic: String,
        candidate: CompiledEntry
    ) -> Double {
        guard tokenCount == 1, candidate.tokens.count == 1 else { return 0 }
        guard isStylizedSingleTokenEntry(candidate) else { return 0 }
        guard observedNormalized.count >= EvaluationStylizedConstants.minimumObservedLength,
              candidate.tokens[0].count >= EvaluationStylizedConstants.minimumCandidateLength else { return 0 }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidate.tokens[0])) else { return 0 }

        let observedFallback = encoder.fallbackSignature(for: observedNormalized)
        let candidateFallback = encoder.fallbackSignature(for: candidate.tokens[0])
        guard !observedFallback.isEmpty, !candidateFallback.isEmpty else { return 0 }

        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidate.phoneticPhrase)
        return max(fallbackSimilarity, runtimeSimilarity)
    }

    func hasStrongStylizedFallbackPhoneticEvidence(
        observed: String,
        candidate: String,
        observedPhonetic: String,
        candidatePhonetic: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= EvaluationStylizedConstants.strongFallbackTextMinimum else { return false }
        let observedFallback = encoder.fallbackSignature(for: observed)
        let candidateFallback = encoder.fallbackSignature(for: candidate)
        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
        return max(fallbackSimilarity, runtimeSimilarity) >= EvaluationStylizedConstants.strongFallbackSimilarityMinimum
    }

    func hasModerateStylizedFallbackPhoneticEvidence(
        observed: String,
        candidate: String,
        observedPhonetic: String,
        candidatePhonetic: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= EvaluationStylizedConstants.moderateFallbackTextMinimum else { return false }
        guard let observedFirst = observed.first?.lowercased(),
              let candidateFirst = candidate.first?.lowercased(),
              observedFirst == candidateFirst else { return false }
        let observedFallback = encoder.fallbackSignature(for: observed)
        let candidateFallback = encoder.fallbackSignature(for: candidate)
        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
        return max(fallbackSimilarity, runtimeSimilarity) >= EvaluationStylizedConstants.moderateFallbackSimilarityMinimum
    }

    func allowStylizedFallbackForCommonObservedToken(
        token: Token,
        tokenIndex: Int,
        totalTokens: Int
    ) -> Bool {
        guard let first = token.raw.first else { return false }
        guard String(first).uppercased() == String(first) else { return false }
        if token.raw.dropFirst().contains(where: { String($0).uppercased() == String($0) }) {
            return true
        }

        // Avoid sentence-start capitalization false positives in prose.
        if tokenIndex == 0, totalTokens > 1 {
            return false
        }

        return true
    }

    func hasStylizedLongPrefixTailGuardEvidence(
        observed: String,
        candidate: String
    ) -> Bool {
        guard observed.count > candidate.count else { return true }

        let sharedPrefixLength = sharedPrefixLength(lhs: observed, rhs: candidate)
        guard sharedPrefixLength >= EvaluationStylizedConstants.longPrefixTailGuardMinimumSharedPrefixLength else {
            return true
        }

        let observedTail = String(observed.dropFirst(sharedPrefixLength))
        let candidateTail = String(candidate.dropFirst(sharedPrefixLength))
        guard !candidateTail.isEmpty else { return false }

        let observedTailPhonetic = encoder.scoringSignature(for: observedTail, lexicon: lexicon)
        let candidateTailPhonetic = encoder.scoringSignature(for: candidateTail, lexicon: lexicon)
        let textSimilarity = scorer.similarity(lhs: observedTail, rhs: candidateTail)
        let phoneticSimilarity = scorer.similarity(lhs: observedTailPhonetic, rhs: candidateTailPhonetic)

        return max(textSimilarity, phoneticSimilarity)
            >= EvaluationStylizedConstants.longPrefixTailGuardMinimumSimilarity
    }

    private func sharedPrefixLength(lhs: String, rhs: String) -> Int {
        zip(lhs, rhs).prefix { $0 == $1 }.count
    }
}
