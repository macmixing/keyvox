extension DictionaryMatcher {
    // A known word that is not pronounced like the entry was said as itself.
    // Missing pronunciation data is intentionally permissive; compare only when both values exist.
    func hasSingleTokenPronunciationEvidence(
        observedToken: String,
        observedForm: String,
        replacementSuffix: String,
        candidate: String
    ) -> Bool {
        guard let candidatePronunciation = lexicon.pronunciation(for: candidate) else { return true }

        if let observedFormPronunciation = lexicon.pronunciation(for: observedForm) {
            return observedFormPronunciation == candidatePronunciation
        }

        guard !replacementSuffix.isEmpty,
              let observedTokenPronunciation = lexicon.pronunciation(for: observedToken) else {
            return true
        }

        // An inflected known word may only add the suffix sound to the entry's pronunciation.
        let observedPhonemes = observedTokenPronunciation.components(separatedBy: PronunciationLexicon.phonemeSeparator)
        let candidatePhonemes = candidatePronunciation.components(separatedBy: PronunciationLexicon.phonemeSeparator)
        return observedPhonemes.count == candidatePhonemes.count + StandardEvaluationPolicy.inflectionSuffixPhonemeCount
            && observedPhonemes.starts(with: candidatePhonemes)
    }
}
