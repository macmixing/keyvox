import Foundation

private enum SplitJoinScoringConstants {
    static let hyphenLaneMinimumFirstTokenLength = 1
    static let hyphenLaneMinimumSecondTokenLength = 4
    static let hyphenLaneTextSimilarityMinimum = 0.62
    static let hyphenLanePhoneticSimilarityMinimum = 0.98
    static let hyphenLaneThreshold = 0.78

    static let possessiveStylizedBonus = 0.04
    static let pluralSplitJoinBonus = 0.06
    static let anchoredStylizedBonus = 0.06

    static let pluralSplitJoinPhoneticMinimum = 0.95
    static let pluralSplitJoinThreshold = 0.84

    static let stylizedStrongTextMinimum = 0.80
    static let stylizedStrongBlendedMinimum = 0.70
    static let stylizedStrongThreshold = 0.74

    static let stylizedModerateTextMinimum = 0.68
    static let stylizedModerateBlendedMinimum = 0.62
    static let stylizedModerateThreshold = 0.62

    static let stylizedAnchoredTextMinimum = 0.40
    static let stylizedAnchoredPhoneticMinimum = 0.60
    static let stylizedAnchoredBlendedMinimum = 0.48
    static let stylizedAnchoredThreshold = 0.44
    static let stylizedAnchoredTailGuardMinimumSecondTokenLength = 4
    static let stylizedAnchoredTailGuardMinimumSimilarity = 0.55

    static let blendedTextWeight = 0.6
    static let blendedPhoneticWeight = 0.4
}

extension DictionaryMatcher {
    func proposeSplitJoinReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        let end = start + 2
        guard end <= tokens.count else { return nil }
        guard let oneTokenCandidates = entriesByTokenCount[1], !oneTokenCandidates.isEmpty else { return nil }

        stats.attempted += 1

        let window = Array(tokens[start..<end])
        if isLikelyDomainTokenSplit(window: window, text: text) {
            return nil
        }
        let forms = splitJoinForms(from: window)
        guard !forms.isEmpty else {
            stats.rejectedLowScore += 1
            return nil
        }

        let isHyphenSingleLetterLane =
            isExplicitHyphenDelimitedSplit(window: window, text: text)
            && window[0].normalized.count == SplitJoinScoringConstants.hyphenLaneMinimumFirstTokenLength
            && window[1].normalized.count >= SplitJoinScoringConstants.hyphenLaneMinimumSecondTokenLength

        let containsShortToken =
            window[0].normalized.count < minimumSplitTokenLength
            || window[1].normalized.count < minimumSplitTokenLength
        if containsShortToken {
            let exactJoinedCandidates = Set(oneTokenCandidates.map(\.normalizedPhrase))
            let hasExactJoinCandidate = forms.contains { form in
                exactJoinedCandidates.contains(form.normalized)
            }
            guard hasExactJoinCandidate || isHyphenSingleLetterLane else {
                stats.rejectedShortToken += 1
                return nil
            }
        }

        var best: Candidate?
        var secondBestScore = 0.0

        for candidate in oneTokenCandidates {
            let candidateToken = candidate.tokens[0]
            let candidateIsCommonWord = lexicon.isCommonWord(candidateToken)

            // If the first token already matches the single-token candidate
            // exactly, split-join must not consume the following token
            // (e.g. "KeyVox, and" -> "KeyVox" or "KeyVox bug" -> "KeyVox").
            if window[0].normalized == candidateToken {
                continue
            }

            for form in forms {
                // Only non-common dictionary entries can use plural-tail singularization.
                if form.singularizedSecondToken && candidateIsCommonWord {
                    continue
                }

                let observedPhonetic = encoder.scoringSignature(for: form.normalized, lexicon: lexicon)
                let score = scorer.score(
                    observedText: form.normalized,
                    observedPhonetic: observedPhonetic,
                    candidateText: candidate.normalizedPhrase,
                    candidatePhonetic: candidate.phoneticPhrase,
                    previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                    nextToken: end < tokens.count ? tokens[end].normalized : nil
                )
                let fallbackPhoneticSimilarity = splitJoinStylizedFallbackPhoneticSimilarity(
                    observedNormalized: form.normalized,
                    observedPhonetic: observedPhonetic,
                    candidate: candidate
                )
                let phoneticDelta = max(0, fallbackPhoneticSimilarity - score.phonetic)
                let adjustedBaseFinal = min(1.0, score.final + (scorer.phoneticWeight * phoneticDelta))
                let possessiveStylizedBonus =
                    (form.replacementSuffix == "'s" && isStylizedSingleTokenEntry(candidate))
                    ? SplitJoinScoringConstants.possessiveStylizedBonus
                    : 0.0
                let pluralSplitJoinBonus =
                    (form.singularizedSecondToken && form.replacementSuffix == "s" && !candidateIsCommonWord)
                    ? SplitJoinScoringConstants.pluralSplitJoinBonus
                    : 0.0
                let anchoredStylizedBonus: Double
                if isStylizedSingleTokenEntry(candidate), candidateToken.hasPrefix(window[0].normalized) {
                    anchoredStylizedBonus = SplitJoinScoringConstants.anchoredStylizedBonus
                } else {
                    anchoredStylizedBonus = 0
                }
                let adjustedScore = ReplacementScore(
                    text: score.text,
                    phonetic: max(score.phonetic, fallbackPhoneticSimilarity),
                    context: score.context,
                    final: min(
                        1.0,
                        adjustedBaseFinal
                            + possessiveBonus(for: form.replacementSuffix)
                            + possessiveStylizedBonus
                            + pluralSplitJoinBonus
                            + anchoredStylizedBonus
                    )
                )

                if let currentBest = best {
                    if adjustedScore.final > currentBest.score.final {
                        secondBestScore = currentBest.score.final
                        best = Candidate(
                            entry: candidate,
                            score: adjustedScore,
                            replacementSuffix: form.replacementSuffix
                        )
                    } else if adjustedScore.final > secondBestScore {
                        secondBestScore = adjustedScore.final
                    }
                } else {
                    best = Candidate(
                        entry: candidate,
                        score: adjustedScore,
                        replacementSuffix: form.replacementSuffix
                    )
                }
            }
        }

        guard let best else {
            stats.rejectedLowScore += 1
            return nil
        }

        let threshold = max(scorer.threshold(for: 2), splitJoinMinimumScore)
        var effectiveThreshold = threshold
        if isHyphenSingleLetterLane {
            let observedJoined = window.map(\.normalized).joined()
            let candidateToken = best.entry.tokens[0]
            let textSimilarity = scorer.similarity(lhs: observedJoined, rhs: candidateToken)
            let observedPhonetic = encoder.scoringSignature(for: observedJoined, lexicon: lexicon)
            let candidatePhonetic = encoder.scoringSignature(for: candidateToken, lexicon: lexicon)
            let phoneticSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)

            let qualifiesHyphenSingleLetterLane =
                !lexicon.isCommonWord(candidateToken)
                && candidateToken.hasSuffix(window[1].normalized)
                && textSimilarity >= SplitJoinScoringConstants.hyphenLaneTextSimilarityMinimum
                && phoneticSimilarity >= SplitJoinScoringConstants.hyphenLanePhoneticSimilarityMinimum

            guard qualifiesHyphenSingleLetterLane else {
                stats.rejectedShortToken += 1
                return nil
            }
            effectiveThreshold = min(effectiveThreshold, SplitJoinScoringConstants.hyphenLaneThreshold)
        }
        if best.replacementSuffix == "s",
           !lexicon.isCommonWord(best.entry.tokens[0]),
           best.score.phonetic >= SplitJoinScoringConstants.pluralSplitJoinPhoneticMinimum {
            // Guarded plural split-join lane for strong homophone evidence
            // (for example "sub queues" -> "subcues").
            effectiveThreshold = min(effectiveThreshold, SplitJoinScoringConstants.pluralSplitJoinThreshold)
        }
        if isStylizedSingleTokenEntry(best.entry) {
            let candidateToken = best.entry.tokens[0]
            let similarity = splitJoinStylizedSimilarity(window: window, candidateToken: candidateToken)

            // Keep split-join strict by default, but allow stylized single-token
            // brand-like entries when both text and phonetic evidence are strong.
            if similarity.text >= SplitJoinScoringConstants.stylizedStrongTextMinimum,
               similarity.blended >= SplitJoinScoringConstants.stylizedStrongBlendedMinimum {
                effectiveThreshold = min(effectiveThreshold, SplitJoinScoringConstants.stylizedStrongThreshold)
            } else if similarity.text >= SplitJoinScoringConstants.stylizedModerateTextMinimum,
                      similarity.blended >= SplitJoinScoringConstants.stylizedModerateBlendedMinimum {
                // Spoken split forms like "air act's" can still be a clean stylized
                // match when fallback phonetic shape is strong.
                effectiveThreshold = min(effectiveThreshold, SplitJoinScoringConstants.stylizedModerateThreshold)
            } else if isAnchoredStylizedSplitJoin(
                window: window,
                candidateToken: candidateToken
            ),
            hasAnchoredStylizedTailGuardEvidence(
                window: window,
                candidateToken: candidateToken
            ),
            similarity.text >= SplitJoinScoringConstants.stylizedAnchoredTextMinimum,
            similarity.phonetic >= SplitJoinScoringConstants.stylizedAnchoredPhoneticMinimum,
            similarity.blended >= SplitJoinScoringConstants.stylizedAnchoredBlendedMinimum {
                // Additional guarded lane for cases where Whisper splits a stylized
                // proper name into two spoken words while the remaining tail still
                // resembles the stylized ending.
                effectiveThreshold = min(effectiveThreshold, SplitJoinScoringConstants.stylizedAnchoredThreshold)
            }
        }

        guard best.score.final >= effectiveThreshold else {
            stats.rejectedLowScore += 1
            return nil
        }

        if secondBestScore > 0,
           (best.score.final - secondBestScore) < scorer.ambiguityMargin {
            stats.rejectedAmbiguity += 1
            return nil
        }

        if lexicon.isCommonWord(best.entry.tokens[0]),
           best.score.final < scorer.commonWordOverrideThreshold {
            stats.rejectedCommonWord += 1
            return nil
        }

        var replacementSuffix = best.replacementSuffix
        if replacementSuffix == "s",
           let candidateToken = best.entry.tokens.first,
           shouldInferSplitJoinPossessiveSuffix(
               observedCombined: window.map(\.normalized).joined(),
               observedTail: window[1].normalized,
               candidate: candidateToken,
               nextToken: end < tokens.count ? tokens[end] : nil
           ) {
            replacementSuffix = "'s"
        }
        if replacementSuffix.isEmpty,
           isStylizedSingleTokenEntry(best.entry),
           let candidateToken = best.entry.tokens.first,
           isAnchoredStylizedSplitJoin(window: window, candidateToken: candidateToken),
           shouldInferSplitJoinPossessiveSuffix(
               observedCombined: window.map(\.normalized).joined(),
               observedTail: window[1].normalized,
               candidate: candidateToken,
               nextToken: end < tokens.count ? tokens[end] : nil
           ) {
            replacementSuffix = "'s"
        }

        let range = combinedRange(from: window)
        let observedRaw = (text as NSString).substring(with: range)
        let normalizedReplacementSuffix = resolvedSplitJoinReplacementSuffix(
            basePhrase: best.entry.phrase,
            desiredSuffix: replacementSuffix
        )
        let replacementText = best.entry.phrase + normalizedReplacementSuffix
        if observedRaw == replacementText {
            return nil
        }

        return ProposedReplacement(
            tokenStart: start,
            tokenEndExclusive: end,
            range: range,
            replacement: replacementText,
            score: best.score.final
        )
    }

    private func splitJoinStylizedFallbackPhoneticSimilarity(
        observedNormalized: String,
        observedPhonetic: String,
        candidate: CompiledEntry
    ) -> Double {
        guard candidate.tokens.count == 1 else { return 0 }
        guard isStylizedSingleTokenEntry(candidate) else { return 0 }
        let candidateToken = candidate.tokens[0]
        guard observedNormalized.count >= 4, candidateToken.count >= 5 else { return 0 }

        let observedFallback = encoder.fallbackSignature(for: observedNormalized)
        let candidateFallback = encoder.fallbackSignature(for: candidateToken)
        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidate.phoneticPhrase)
        return max(fallbackSimilarity, runtimeSimilarity)
    }

    private func splitJoinStylizedSimilarity(window: [Token], candidateToken: String) -> (text: Double, phonetic: Double, blended: Double) {
        let forms = splitJoinForms(from: window)
        guard !forms.isEmpty else { return (0, 0, 0) }

        var bestText = 0.0
        var bestPhonetic = 0.0
        var bestBlended = 0.0

        for form in forms {
            let textSimilarity = scorer.similarity(lhs: form.normalized, rhs: candidateToken)
            let observedPhonetic = encoder.scoringSignature(for: form.normalized, lexicon: lexicon)
            let candidatePhonetic = encoder.scoringSignature(for: candidateToken, lexicon: lexicon)
            let runtimePhoneticSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
            let observedFallback = encoder.fallbackSignature(for: form.normalized)
            let candidateFallback = encoder.fallbackSignature(for: candidateToken)
            let fallbackPhoneticSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
            let phoneticSimilarity = max(runtimePhoneticSimilarity, fallbackPhoneticSimilarity)
            let blended = (SplitJoinScoringConstants.blendedTextWeight * textSimilarity)
                + (SplitJoinScoringConstants.blendedPhoneticWeight * phoneticSimilarity)

            bestText = max(bestText, textSimilarity)
            bestPhonetic = max(bestPhonetic, phoneticSimilarity)
            bestBlended = max(bestBlended, blended)
        }

        return (bestText, bestPhonetic, bestBlended)
    }

    private func hasAnchoredStylizedTailGuardEvidence(window: [Token], candidateToken: String) -> Bool {
        guard window.count == 2 else { return false }

        let observedPrefix = window[0].normalized
        guard candidateToken.hasPrefix(observedPrefix) else { return false }

        let observedTail = window[1].normalized
        guard observedTail.count >= SplitJoinScoringConstants.stylizedAnchoredTailGuardMinimumSecondTokenLength else {
            return true
        }

        // Long ordinary words are the riskiest anchored split-join false positives,
        // so require the unmatched tail to still resemble the brand tail.
        let candidateTail = String(candidateToken.dropFirst(observedPrefix.count))
        guard !candidateTail.isEmpty else { return false }

        let observedTailPhonetic = encoder.scoringSignature(for: observedTail, lexicon: lexicon)
        let candidateTailPhonetic = encoder.scoringSignature(for: candidateTail, lexicon: lexicon)
        let textSimilarity = scorer.similarity(lhs: observedTail, rhs: candidateTail)
        let phoneticSimilarity = scorer.similarity(lhs: observedTailPhonetic, rhs: candidateTailPhonetic)

        return max(textSimilarity, phoneticSimilarity)
            >= SplitJoinScoringConstants.stylizedAnchoredTailGuardMinimumSimilarity
    }
}
