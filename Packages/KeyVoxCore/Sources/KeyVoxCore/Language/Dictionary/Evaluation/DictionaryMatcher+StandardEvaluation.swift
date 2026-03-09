import Foundation
import NaturalLanguage

private enum StandardEvaluationConstants {
    static let minimumSingleTokenLength = 3

    static let pluralHomophonePhoneticMinimum = 0.95
    static let pluralHomophoneTextMinimum = 0.35
    static let pluralHomophoneBonus = 0.14

    static let singleTokenPossessiveMinimumThreshold = 0.82
    static let singleTokenPossessiveThresholdDelta = 0.08
    static let singleTokenPluralPhoneticMinimum = 0.92
    static let singleTokenPluralMinimumThreshold = 0.78
    static let singleTokenPluralThresholdDelta = 0.12
    static let twoTokenPossessiveMinimumThreshold = 0.70
    static let twoTokenPossessiveThresholdDelta = 0.10

    static let peerSupportSimilarityMaximum = 0.70
    static let stylizedSurfaceSimilarityMinimum = 0.82
    static let stylizedStrongTextThreshold = 0.50
    static let stylizedStrongFallbackThreshold = 0.60
    static let stylizedModerateFallbackThreshold = 0.55
    static let stylizedStrongSurfaceThreshold = 0.72
    static let properNounSimilarityMinimum = 0.80
    static let properNounBlendedSimilarityMinimum = 0.74
    static let properNounThreshold = 0.78

    static let twoTokenStrongEvidenceThreshold = 0.72
    static let twoTokenModerateEvidenceThreshold = 0.55

    static let commonWordStylizedBypassMinimum = 0.82
    static let commonWordFallbackBypassMinimum = 0.58
    static let commonWordStructuralBypassMinimum = 0.60
    static let commonWordStructuralContextThreshold = 0.60
    static let commonWordAttributionContextThreshold = 0.62
    static let structuralLeftContextMaximumLength = 4
    static let structuralRightContextMinimumLength = 7
    static let lowercaseAlphabeticTokenRegex = try! NSRegularExpression(pattern: #"^[a-z]+$"#)
}

extension DictionaryMatcher {
    private func hasAttributionLikePrepositionContext(tokenStart: Int, tokens: [Token]) -> Bool {
        guard tokenStart >= 2 else { return false }
        return tokens[tokenStart - 1].lexicalClass == .preposition
            && tokens[tokenStart - 2].lexicalClass == .noun
    }

    private func hasStructuralCommonWordBrandContext(
        tokenStart: Int,
        tokenEndExclusive: Int,
        tokens: [Token]
    ) -> Bool {
        guard tokenStart > 0, tokenEndExclusive < tokens.count else { return false }
        let leftToken = tokens[tokenStart - 1]
        let rightToken = tokens[tokenEndExclusive]
        let left = leftToken.normalized
        let right = rightToken.normalized
        let rightRange = NSRange(location: 0, length: right.utf16.count)
        let rightIsLowerAlphabetic = StandardEvaluationConstants.lowercaseAlphabeticTokenRegex.firstMatch(
            in: right,
            options: [],
            range: rightRange
        ) != nil
        let leftIsVerb = leftToken.lexicalClass == .verb
        let rightIsVerbLike = rightToken.lexicalClass == .verb || rightToken.lexicalClass == .adjective

        return left.count <= StandardEvaluationConstants.structuralLeftContextMaximumLength
            && leftIsVerb
            && rightIsLowerAlphabetic
            && right.count >= StandardEvaluationConstants.structuralRightContextMinimumLength
            && rightIsVerbLike
    }

    func proposeStandardReplacement(
        start: Int,
        tokenCount: Int,
        tokens: [Token],
        text: String,
        candidates: [CompiledEntry],
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        stats.attempted += 1

        let end = start + tokenCount
        let window = Array(tokens[start..<end])
        let observedNormalized = window.map(\.normalized).joined(separator: " ")
        let observedPhonetic = window.map(\.phonetic).joined(separator: " ")
        let observedForms = observedFormsForWindow(
            tokenCount: tokenCount,
            window: window,
            observedNormalized: observedNormalized,
            observedPhonetic: observedPhonetic
        )

        var best: Candidate?
        var bestObservedNormalized: String?
        var secondBestScore = 0.0

        for candidate in candidates {
            var bestForCandidate: Candidate?
            var bestObservedNormalizedForCandidate: String?
            for form in observedForms {
                let baseScore = scorer.score(
                    observedText: form.normalized,
                    observedPhonetic: form.phonetic,
                    candidateText: candidate.normalizedPhrase,
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
                        tokenIndex: start,
                        totalTokens: tokens.count
                    )
                let gatedFallbackPhoneticSimilarity =
                    allowStylizedFallbackBySurface ? fallbackPhoneticSimilarity : 0
                let phoneticDelta = max(0, gatedFallbackPhoneticSimilarity - baseScore.phonetic)
                let adjustedBaseFinal = min(1.0, baseScore.final + (scorer.phoneticWeight * phoneticDelta))
                let adjustedPhoneticScore = max(baseScore.phonetic, gatedFallbackPhoneticSimilarity)
                let pluralHomophoneBonus: Double
                if tokenCount == 1,
                   form.replacementSuffix == "s",
                   candidate.tokens.count == 1,
                   !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidate.tokens[0])),
                   adjustedPhoneticScore >= StandardEvaluationConstants.pluralHomophonePhoneticMinimum,
                   baseScore.text >= StandardEvaluationConstants.pluralHomophoneTextMinimum {
                    // Deterministic lane for plural homophone near-misses such as
                    // "queues" -> "cues" when the dictionary term is singular.
                    pluralHomophoneBonus = StandardEvaluationConstants.pluralHomophoneBonus
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
                    }
                } else {
                    bestForCandidate = candidateScore
                    bestObservedNormalizedForCandidate = form.normalized
                }
            }

            guard let bestForCandidate else { continue }
            if let currentBest = best {
                if bestForCandidate.score.final > currentBest.score.final {
                    secondBestScore = currentBest.score.final
                    best = bestForCandidate
                    bestObservedNormalized = bestObservedNormalizedForCandidate
                } else if bestForCandidate.score.final > secondBestScore {
                    secondBestScore = bestForCandidate.score.final
                }
            } else {
                best = bestForCandidate
                bestObservedNormalized = bestObservedNormalizedForCandidate
            }
        }

        guard let best, let bestObservedNormalized else { return nil }

        let exactMatch = observedNormalized == best.entry.normalizedPhrase

        if tokenCount == 1,
           window[0].normalized.count < StandardEvaluationConstants.minimumSingleTokenLength,
           !exactMatch {
            stats.rejectedShortToken += 1
            return nil
        }

        let threshold = scorer.threshold(for: tokenCount)
        var effectiveThreshold: Double
        if tokenCount == 1, best.replacementSuffix == "'s" {
            // Possessive tails add noise; allow a slightly lower gate while keeping
            // common-word and ambiguity guards intact.
            effectiveThreshold = max(
                StandardEvaluationConstants.singleTokenPossessiveMinimumThreshold,
                threshold - StandardEvaluationConstants.singleTokenPossessiveThresholdDelta
            )
        } else if tokenCount == 1,
                  best.replacementSuffix == "s",
                  best.score.phonetic >= StandardEvaluationConstants.singleTokenPluralPhoneticMinimum {
            // Spoken plurals can be transcribed as close homophones ("queues" vs "cues");
            // allow a guarded lane when phonetic evidence is very strong.
            effectiveThreshold = max(
                StandardEvaluationConstants.singleTokenPluralMinimumThreshold,
                threshold - StandardEvaluationConstants.singleTokenPluralThresholdDelta
            )
        } else if tokenCount == 2, best.replacementSuffix == "'s" {
            // Two-token possessive near-misses can lose apostrophes in Whisper output.
            // Keep this tighter than single-token possessives but allow a modest lift.
            effectiveThreshold = max(
                StandardEvaluationConstants.twoTokenPossessiveMinimumThreshold,
                threshold - StandardEvaluationConstants.twoTokenPossessiveThresholdDelta
            )
        } else {
            effectiveThreshold = threshold
        }
        var requiresPeerSupport = false
        var singleTokenCandidatePhonetic: String?

        if tokenCount == 1 {
            let observedToken = window[0]
            let candidateToken = best.entry.tokens[0]
            let candidatePhonetic = encoder.scoringSignature(for: candidateToken, lexicon: lexicon)
            singleTokenCandidatePhonetic = candidatePhonetic
            let textSimilarity = scorer.similarity(lhs: observedToken.normalized, rhs: candidateToken)
            let phoneticSimilarity = scorer.similarity(lhs: observedToken.phonetic, rhs: candidatePhonetic)
            let isCommonWord = lexicon.isCommonWord(baseTokenForCommonWordGuard(observedToken.normalized))
            let stylizedSingleTokenEntry = isStylizedSingleTokenEntry(best.entry)
            let observedHasRuntimePronunciation = lexicon.pronunciation(for: observedToken.normalized) != nil
            let hasStructuralContext = hasStructuralCommonWordBrandContext(
                tokenStart: start,
                tokenEndExclusive: end,
                tokens: tokens
            )
            let hasAttributionPrepositionContext = hasAttributionLikePrepositionContext(
                tokenStart: start,
                tokens: tokens
            )
            let allowStylizedFallbackBySurface =
                allowStylizedFallbackForCommonObservedToken(
                    token: observedToken,
                    tokenIndex: start,
                    totalTokens: tokens.count
                )

            if observedHasRuntimePronunciation,
               isCommonWord,
               !stylizedSingleTokenEntry,
               textSimilarity < StandardEvaluationConstants.peerSupportSimilarityMaximum {
                // Guard risky common-word -> brand hops unless corroborated by another
                // independent replacement in the same utterance.
                requiresPeerSupport = true
            }

            if stylizedSingleTokenEntry,
               !allowStylizedFallbackBySurface,
               !hasStructuralContext,
               textSimilarity < StandardEvaluationConstants.stylizedSurfaceSimilarityMinimum {
                stats.rejectedLowScore += 1
                return nil
            }

            if stylizedSingleTokenEntry,
               !hasStylizedLongPrefixTailGuardEvidence(
                    observed: bestObservedNormalized,
                    candidate: candidateToken
               ) {
                stats.rejectedLowScore += 1
                return nil
            }

            if isCommonWord {
                if hasStructuralContext {
                    effectiveThreshold = min(
                        effectiveThreshold,
                        StandardEvaluationConstants.commonWordStructuralContextThreshold
                    )
                }
                if hasAttributionPrepositionContext {
                    effectiveThreshold = min(
                        effectiveThreshold,
                        StandardEvaluationConstants.commonWordAttributionContextThreshold
                    )
                }
            }

            if stylizedSingleTokenEntry,
               observedToken.normalized.count >= 4,
               candidateToken.count >= 5 {
                if hasStrongStylizedTextEvidence(
                    observed: observedToken.normalized,
                    candidate: candidateToken,
                    textSimilarity: textSimilarity
                ) {
                    // Runtime lexicon pronunciations can disagree on letter-level
                    // edits (e.g. one-character brand near-misses). If stylized
                    // text evidence is very strong, avoid over-penalizing phonetics.
                    effectiveThreshold = min(effectiveThreshold, StandardEvaluationConstants.stylizedStrongTextThreshold)
                } else if textSimilarity >= StandardEvaluationConstants.stylizedSurfaceSimilarityMinimum {
                    // Runtime lexicon coverage can vary; keep stylized single-token
                    // brand corrections resilient when text evidence is strong.
                    effectiveThreshold = min(effectiveThreshold, StandardEvaluationConstants.stylizedStrongSurfaceThreshold)
                } else if hasStrongStylizedFallbackPhoneticEvidence(
                    observed: observedToken.normalized,
                    candidate: candidateToken,
                    observedPhonetic: observedToken.phonetic,
                    candidatePhonetic: candidatePhonetic,
                    textSimilarity: textSimilarity
                ), allowStylizedFallbackBySurface {
                    // Runtime lexicon phonemes for proper nouns can be sparse or absent.
                    // If fallback grapheme-phonetic evidence is very strong, permit a
                    // lower gate for stylized dictionary terms.
                    effectiveThreshold = min(effectiveThreshold, StandardEvaluationConstants.stylizedStrongFallbackThreshold)
                } else if hasModerateStylizedFallbackPhoneticEvidence(
                    observed: observedToken.normalized,
                    candidate: candidateToken,
                    observedPhonetic: observedToken.phonetic,
                    candidatePhonetic: candidatePhonetic,
                    textSimilarity: textSimilarity
                ), allowStylizedFallbackBySurface {
                    // Allow an additional conservative lane for all-caps/near-miss
                    // stylized tokens that preserve start anchoring and fallback shape.
                    effectiveThreshold = min(effectiveThreshold, StandardEvaluationConstants.stylizedModerateFallbackThreshold)
                }
            }

            // Generic hardening for proper-noun-like single tokens when hinting is absent:
            // require longer non-common tokens plus strong text/phonetic agreement.
            if !isCommonWord,
               observedToken.normalized.count >= 5,
               candidateToken.count >= 5,
               max(textSimilarity, phoneticSimilarity) >= StandardEvaluationConstants.properNounSimilarityMinimum,
               ((0.6 * textSimilarity) + (0.4 * phoneticSimilarity)) >= StandardEvaluationConstants.properNounBlendedSimilarityMinimum {
                effectiveThreshold = min(effectiveThreshold, StandardEvaluationConstants.properNounThreshold)
            }

        } else if tokenCount == 2,
                  best.entry.tokens.count == 2 {
            if hasStrongAnchoredTwoTokenEvidence(window: window, candidate: best.entry) {
                // Runtime pronunciations for proper nouns can be sparse. When the first
                // token anchors exactly and the second token is strongly similar, allow
                // the match through a slightly lower gate.
                effectiveThreshold = min(effectiveThreshold, StandardEvaluationConstants.twoTokenStrongEvidenceThreshold)
            } else if hasModerateAnchoredTwoTokenEvidence(window: window, candidate: best.entry) {
                // Some near-miss surname variants are close in spelling shape but can
                // diverge in runtime lexicon phonetics. Keep this fallback conservative
                // with exact first-token anchoring and non-common long-tail requirements.
                effectiveThreshold = min(effectiveThreshold, StandardEvaluationConstants.twoTokenModerateEvidenceThreshold)
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

        if tokenCount == 1,
           lexicon.isCommonWord(baseTokenForCommonWordGuard(window[0].normalized)) {
            let allowStylizedBySurface = allowStylizedFallbackForCommonObservedToken(
                token: window[0],
                tokenIndex: start,
                totalTokens: tokens.count
            )
            let hasStructuralContext = hasStructuralCommonWordBrandContext(
                tokenStart: start,
                tokenEndExclusive: end,
                tokens: tokens
            )
            let stylizedCommonWordWithoutSurfaceEvidence =
                isStylizedSingleTokenEntry(best.entry)
                && !allowStylizedBySurface
            let hasAttributionPrepositionContext = hasAttributionLikePrepositionContext(tokenStart: start, tokens: tokens)
            if !isStylizedSingleTokenEntry(best.entry),
               !hasStructuralContext,
               !hasAttributionPrepositionContext {
                stats.rejectedCommonWord += 1
                return nil
            }
            let stylizedStructuralBypass =
                stylizedCommonWordWithoutSurfaceEvidence
                && hasStructuralContext
                && best.score.final >= StandardEvaluationConstants.commonWordStructuralBypassMinimum
            if stylizedCommonWordWithoutSurfaceEvidence {
                // Common prose tokens that only match via fallback phonetics should
                // need independent clause-local evidence before replacing.
                requiresPeerSupport = !stylizedStructuralBypass
            }
            var stylizedBrandBypass =
                isStylizedSingleTokenEntry(best.entry)
                && allowStylizedBySurface
                && best.score.final >= StandardEvaluationConstants.commonWordStylizedBypassMinimum
            stylizedBrandBypass = stylizedBrandBypass || stylizedStructuralBypass
            if !stylizedBrandBypass,
               isStylizedSingleTokenEntry(best.entry),
               allowStylizedBySurface,
               let candidateToken = best.entry.tokens.first,
               let candidatePhonetic = singleTokenCandidatePhonetic {
                let textSimilarity = scorer.similarity(lhs: window[0].normalized, rhs: candidateToken)
                if hasStrongStylizedFallbackPhoneticEvidence(
                    observed: window[0].normalized,
                    candidate: candidateToken,
                    observedPhonetic: window[0].phonetic,
                    candidatePhonetic: candidatePhonetic,
                    textSimilarity: textSimilarity
                ), best.score.final >= StandardEvaluationConstants.commonWordFallbackBypassMinimum {
                    stylizedBrandBypass = true
                }
            }
            if !stylizedBrandBypass,
               best.score.final < scorer.commonWordOverrideThreshold {
                if hasStructuralContext {
                    requiresPeerSupport = false
                } else if stylizedCommonWordWithoutSurfaceEvidence || hasAttributionPrepositionContext {
                    requiresPeerSupport = true
                } else if !requiresPeerSupport {
                    stats.rejectedCommonWord += 1
                    return nil
                }
            }
        }

        var tokenEndExclusive = end
        var range = combinedRange(from: window)
        if shouldConsumeSplitTailToken(window: window, candidate: best.entry, nextToken: end < tokens.count ? tokens[end] : nil) {
            tokenEndExclusive = end + 1
            range = combinedRange(from: Array(tokens[start..<tokenEndExclusive]))
        }

        var replacementSuffix = best.replacementSuffix
        if replacementSuffix.isEmpty,
           tokenCount == 1,
           isStylizedSingleTokenEntry(best.entry),
           let candidateToken = best.entry.tokens.first {
            let nextToken = end < tokens.count ? tokens[end] : nil
            if shouldInferPossessiveSuffix(
                observed: window[0].normalized,
                observedPhonetic: window[0].phonetic,
                candidate: candidateToken,
                nextToken: nextToken
            ) {
                replacementSuffix = "'s"
            }
        }

        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase + replacementSuffix

        if observedRaw == replacementText {
            return nil
        }

        return ProposedReplacement(
            tokenStart: start,
            tokenEndExclusive: tokenEndExclusive,
            range: range,
            replacement: replacementText,
            score: best.score.final,
            requiresPeerSupport: requiresPeerSupport
        )
    }
}
