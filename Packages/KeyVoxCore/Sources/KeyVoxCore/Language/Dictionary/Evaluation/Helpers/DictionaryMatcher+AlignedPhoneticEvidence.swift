extension DictionaryMatcher {
    func hasRequiredAlignedTokenPhonetics(
        observedText: String,
        candidateText: String
    ) -> Bool {
        let observedTokens = observedText.split(separator: " ").map(String.init)
        let candidateTokens = candidateText.split(separator: " ").map(String.init)

        guard observedTokens.count > 1,
              observedTokens.count == candidateTokens.count else {
            return true
        }

        return zip(observedTokens, candidateTokens).allSatisfy { observed, candidate in
            guard observed != candidate else { return true }

            let observedPhonetic = encoder.scoringSignature(for: observed, lexicon: lexicon)
            let candidatePhonetic = encoder.scoringSignature(for: candidate, lexicon: lexicon)
            let observedFallback = encoder.fallbackSignature(for: observed)
            let candidateFallback = encoder.fallbackSignature(for: candidate)
            let similarity = max(
                scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic),
                scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
            )

            return similarity >= scorer.minimumPhoneticSimilarity
        }
    }
}
