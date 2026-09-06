import Foundation

extension DictionaryMatcher {
    struct StandardCandidateSelection {
        let candidate: Candidate
        let observedNormalized: String
        let usesCandidateRelativeTrailingForm: Bool
        let secondBestScore: Double
    }

    func selectBestStandardCandidate(
        start: Int,
        tokenCount: Int,
        tokens: [Token],
        text: String,
        candidates: [CompiledEntry],
        window: [Token],
        observedNormalized: String,
        observedPhonetic: String
    ) -> StandardCandidateSelection? {
        let end = start + tokenCount
        let observedForms = observedFormsForWindow(
            tokenCount: tokenCount,
            window: window,
            observedNormalized: observedNormalized,
            observedPhonetic: observedPhonetic
        )
        let hasDirectExactCandidate = candidates.contains { candidate in
            candidate.matchingNormalizedPhrases.contains(observedNormalized)
        }
        let baseCandidateObservedForms = observedForms.map { form in
            (
                normalized: form.normalized,
                phonetic: form.phonetic,
                replacementSuffix: form.replacementSuffix,
                numericSourceTokens: form.numericSourceTokens,
                isCandidateRelativeTrailingForm: false
            )
        }

        var best: Candidate?
        var bestObservedNormalized: String?
        var bestUsesCandidateRelativeTrailingForm = false
        var secondBestScore = 0.0

        for candidate in candidates {
            var bestForCandidate: Candidate?
            var bestObservedNormalizedForCandidate: String?
            var bestForCandidateUsesCandidateRelativeTrailingForm = false
            var candidateObservedForms = baseCandidateObservedForms
            if tokenCount == 1,
               !hasDirectExactCandidate,
               let trailingForm = candidateRelativeTrailingForm(
                   observedNormalized: observedNormalized,
                   candidate: candidate
               ) {
                candidateObservedForms.append((
                    normalized: trailingForm.normalized,
                    phonetic: trailingForm.phonetic,
                    replacementSuffix: trailingForm.replacementSuffix,
                    numericSourceTokens: trailingForm.numericSourceTokens,
                    isCandidateRelativeTrailingForm: true
                ))
            }
            for candidateText in candidate.matchingNormalizedPhrases {
                for form in candidateObservedForms {
                    guard hasSufficientNumericAlignment(
                        observedNormalized: form.normalized,
                        observedNumericSourceTokens: form.numericSourceTokens,
                        candidate: candidate
                    ) else {
                        continue
                    }

                    let baseScore = scorer.score(
                        observedText: form.normalized,
                        observedPhonetic: form.phonetic,
                        candidateText: candidateText,
                        candidatePhonetic: candidate.phoneticPhrase,
                        previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                        nextToken: end < tokens.count ? tokens[end].normalized : nil
                    )

                    let fallbackPhoneticSimilarity = stylizedFallbackPhoneticSimilarity(
                        tokenCount: tokenCount,
                        observedNormalized: form.normalized,
                        observedPhonetic: form.phonetic,
                        candidate: candidate
                    )
                    let allowStylizedFallbackBySurface =
                        tokenCount != 1
                        || !isStylizedSingleTokenEntry(candidate)
                        || allowStylizedFallbackForCommonObservedToken(
                            token: window[0],
                            isAtSentenceStartInMultiTokenText: isAtSentenceStartInMultiTokenText(
                                tokenIndex: start,
                                tokens: tokens,
                                text: text
                            )
                        )
                        || hasStrongStylizedTextEvidence(
                            observed: form.normalized,
                            candidate: candidateText,
                            textSimilarity: baseScore.text
                        )
                    let gatedFallbackPhoneticSimilarity =
                        allowStylizedFallbackBySurface ? fallbackPhoneticSimilarity : 0
                    let phoneticDelta = max(0, gatedFallbackPhoneticSimilarity - baseScore.phonetic)
                    let adjustedBaseFinal = min(1.0, baseScore.final + (scorer.phoneticWeight * phoneticDelta))
                    let adjustedPhoneticScore = max(baseScore.phonetic, gatedFallbackPhoneticSimilarity)
                    guard hasRequiredAlignedTokenPhonetics(
                        observedText: form.normalized,
                        candidateText: candidateText
                    ) else {
                        continue
                    }
                    guard scorer.hasRequiredPhoneticSimilarity(
                        observedText: form.normalized,
                        candidateText: candidateText,
                        phoneticSimilarity: adjustedPhoneticScore
                    ) else {
                        continue
                    }
                    let pluralHomophoneBonus: Double
                    if tokenCount == 1,
                       form.replacementSuffix == "s",
                       candidate.tokens.count == 1,
                       !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidate.tokens[0])),
                       adjustedPhoneticScore >= StandardEvaluationPolicy.pluralHomophonePhoneticMinimum,
                       baseScore.text >= StandardEvaluationPolicy.pluralHomophoneTextMinimum,
                       hasPluralHomophonePronunciationEvidence(
                           observed: form.normalized,
                           candidate: candidate.tokens[0]
                       ) {
                        // Deterministic lane for plural homophone near-misses such as
                        // "queues" -> "cues" when the dictionary term is singular.
                        pluralHomophoneBonus = StandardEvaluationPolicy.pluralHomophoneBonus
                    } else {
                        pluralHomophoneBonus = 0
                    }

                    let boostedFinalScore = min(
                        1.0,
                        adjustedBaseFinal
                            + tokenAlignmentBoost(window: window, candidate: candidate)
                            + possessiveBonus(for: form.replacementSuffix)
                            + pluralHomophoneBonus
                    )
                    let score = ReplacementScore(
                        text: baseScore.text,
                        phonetic: adjustedPhoneticScore,
                        context: baseScore.context,
                        final: boostedFinalScore
                    )

                    let candidateScore = Candidate(
                        entry: candidate,
                        score: score,
                        replacementSuffix: form.replacementSuffix
                    )
                    if let currentBestForCandidate = bestForCandidate {
                        if candidateScore.score.final > currentBestForCandidate.score.final {
                            bestForCandidate = candidateScore
                            bestObservedNormalizedForCandidate = form.normalized
                            bestForCandidateUsesCandidateRelativeTrailingForm = form.isCandidateRelativeTrailingForm
                        }
                    } else {
                        bestForCandidate = candidateScore
                        bestObservedNormalizedForCandidate = form.normalized
                        bestForCandidateUsesCandidateRelativeTrailingForm = form.isCandidateRelativeTrailingForm
                    }
                }
            }

            guard let bestForCandidate else { continue }
            if let currentBest = best {
                if bestForCandidate.score.final > currentBest.score.final {
                    secondBestScore = currentBest.score.final
                    best = bestForCandidate
                    bestObservedNormalized = bestObservedNormalizedForCandidate
                    bestUsesCandidateRelativeTrailingForm = bestForCandidateUsesCandidateRelativeTrailingForm
                } else if bestForCandidate.score.final > secondBestScore {
                    secondBestScore = bestForCandidate.score.final
                }
            } else {
                best = bestForCandidate
                bestObservedNormalized = bestObservedNormalizedForCandidate
                bestUsesCandidateRelativeTrailingForm = bestForCandidateUsesCandidateRelativeTrailingForm
            }
        }

        guard let best, let bestObservedNormalized else { return nil }
        return StandardCandidateSelection(
            candidate: best,
            observedNormalized: bestObservedNormalized,
            usesCandidateRelativeTrailingForm: bestUsesCandidateRelativeTrailingForm,
            secondBestScore: secondBestScore
        )
    }

    private func candidateRelativeTrailingForm(
        observedNormalized: String,
        candidate: CompiledEntry
    ) -> (normalized: String, phonetic: String, replacementSuffix: String, numericSourceTokens: [String?])? {
        guard candidate.tokens.count == 1,
              isStylizedSingleTokenEntry(candidate),
              let candidateToken = candidate.tokens.first,
              observedNormalized.hasPrefix(candidateToken),
              observedNormalized != candidateToken else {
            return nil
        }

        let trailingExtension = String(observedNormalized.dropFirst(candidateToken.count))
        guard !trailingExtension.isEmpty,
              trailingExtension.count < StandardEvaluationPolicy.minimumSingleTokenLength,
              candidateToken.count > trailingExtension.count,
              !lexicon.isCommonWord(observedNormalized) else {
            return nil
        }

        let observedPhonetic = encoder.scoringSignature(for: observedNormalized, lexicon: lexicon)
        let candidatePhonetic = encoder.scoringSignature(for: candidateToken, lexicon: lexicon)
        let observedFallback = encoder.fallbackSignature(for: observedNormalized)
        let candidateFallback = encoder.fallbackSignature(for: candidateToken)
        let phoneticSimilarity = max(
            scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic),
            scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        )
        let minimumPhoneticSimilarity = max(
            StandardEvaluationPolicy.properNounSimilarityMinimum,
            scorer.minimumPhoneticSimilarity
        )
        guard phoneticSimilarity >= minimumPhoneticSimilarity else {
            return nil
        }

        return (
            normalized: candidateToken,
            phonetic: candidatePhonetic,
            replacementSuffix: trailingExtension,
            numericSourceTokens: [nil]
        )
    }

    // Missing pronunciation data is intentionally permissive; compare only when both values exist.
    private func hasPluralHomophonePronunciationEvidence(observed: String, candidate: String) -> Bool {
        guard let observedPronunciation = lexicon.pronunciation(for: observed),
              let candidatePronunciation = lexicon.pronunciation(for: candidate) else {
            return true
        }

        return observedPronunciation == candidatePronunciation
    }
}
