extension DictionaryMatcher {
    func standardEffectiveThreshold(
        tokenCount: Int,
        candidate: Candidate
    ) -> Double {
        let threshold = scorer.threshold(for: tokenCount)
        if tokenCount == 1, candidate.replacementSuffix == "'s" {
            // Possessive tails add noise; allow a slightly lower gate while keeping
            // common-word and ambiguity guards intact.
            return max(
                StandardEvaluationPolicy.singleTokenPossessiveMinimumThreshold,
                threshold - StandardEvaluationPolicy.singleTokenPossessiveThresholdDelta
            )
        }
        if tokenCount == 1,
           candidate.replacementSuffix == "s",
           candidate.score.phonetic >= StandardEvaluationPolicy.singleTokenPluralPhoneticMinimum {
            // Spoken plurals can be transcribed as close homophones ("queues" vs "cues");
            // allow a guarded lane when phonetic evidence is very strong.
            return max(
                StandardEvaluationPolicy.singleTokenPluralMinimumThreshold,
                threshold - StandardEvaluationPolicy.singleTokenPluralThresholdDelta
            )
        }
        return threshold
    }

    func adjustedStandardThresholdForTwoTokenCandidate(
        window: [Token],
        candidate: CompiledEntry,
        effectiveThreshold: Double
    ) -> Double {
        if hasStrongAnchoredTwoTokenEvidence(window: window, candidate: candidate) {
            // Runtime pronunciations for proper nouns can be sparse. When the first
            // token anchors exactly and the second token is strongly similar, allow
            // the match through a slightly lower gate.
            return min(effectiveThreshold, StandardEvaluationPolicy.twoTokenStrongEvidenceThreshold)
        }
        if hasExactTailStylizedHeadEvidence(window: window, candidate: candidate) {
            return min(effectiveThreshold, StandardEvaluationPolicy.twoTokenExactTailStylizedThreshold)
        }
        if hasModerateAnchoredTwoTokenEvidence(window: window, candidate: candidate) {
            // Some near-miss surname variants are close in spelling shape but can
            // diverge in runtime lexicon phonetics. Keep this fallback conservative
            // with exact first-token anchoring and non-common long-tail requirements.
            return min(effectiveThreshold, StandardEvaluationPolicy.twoTokenModerateEvidenceThreshold)
        }
        return effectiveThreshold
    }
}
