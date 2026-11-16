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

            guard similarity >= scorer.minimumPhoneticSimilarity else { return false }

            // A known word pronounced differently from the entry word was said as itself. A misspelled name keeps
            // the entry word's consonant sounds and stays close in spelling, so only that vowel drift may stand in.
            // Missing pronunciation data is intentionally permissive.
            guard let observedPronunciation = lexicon.pronunciation(for: observed),
                  let candidatePronunciation = lexicon.pronunciation(for: candidate),
                  observedPronunciation != candidatePronunciation else {
                return true
            }
            // An inflected entry word is the entry word, and a number word may name the entry word's ordinal.
            if pronunciation(observedPronunciation, addsOneEndingSoundTo: candidatePronunciation) {
                return true
            }
            if DictionaryNumericMatching.isNumberToken(observed),
               pronunciation(candidatePronunciation, addsOneEndingSoundTo: observedPronunciation) {
                return true
            }
            return encoder.consonantPhonemes(inPronunciation: observedPronunciation)
                == encoder.consonantPhonemes(inPronunciation: candidatePronunciation)
                && scorer.transpositionAwareSimilarity(lhs: observed, rhs: candidate)
                    >= StandardEvaluationPolicy.vowelDriftSpellingSimilarityMinimum
        }
    }

    func pronunciation(_ extendedPronunciation: String, addsOneEndingSoundTo basePronunciation: String) -> Bool {
        let basePhonemes = basePronunciation.components(separatedBy: PronunciationLexicon.phonemeSeparator)
        let extendedPhonemes = extendedPronunciation.components(separatedBy: PronunciationLexicon.phonemeSeparator)
        return extendedPhonemes.count == basePhonemes.count + StandardEvaluationPolicy.inflectionSuffixPhonemeCount
            && extendedPhonemes.starts(with: basePhonemes)
    }
}
