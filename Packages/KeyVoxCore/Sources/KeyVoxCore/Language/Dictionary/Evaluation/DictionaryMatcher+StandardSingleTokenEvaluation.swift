import NaturalLanguage

extension DictionaryMatcher {
    struct StandardSingleTokenEvaluation {
        let effectiveThreshold: Double
        let requiresPeerSupport: Bool
        let requiresPeerSupportForTitlecaseKnownWord: Bool
        let candidatePhonetic: String
    }

    enum CommonWordGuardOutcome {
        case rejected
        case allowed(requiresPeerSupport: Bool)
    }

    func evaluateStandardSingleToken(
        start: Int,
        tokens: [Token],
        text: String,
        window: [Token],
        selection: StandardCandidateSelection,
        effectiveThreshold: Double,
        stats: inout DebugStats
    ) -> StandardSingleTokenEvaluation? {
        let end = start + 1
        let best = selection.candidate
        let observedToken = window[0]
        let candidateToken = best.entry.tokens[0]
        let candidatePhonetic = encoder.scoringSignature(for: candidateToken, lexicon: lexicon)
        let surfaceObservedNormalized = selection.usesCandidateRelativeTrailingForm
            ? selection.observedNormalized
            : observedToken.normalized
        let textSimilarity = scorer.similarity(lhs: surfaceObservedNormalized, rhs: candidateToken)
        let phoneticSimilarity = scorer.similarity(lhs: observedToken.phonetic, rhs: candidatePhonetic)
        let isCommonWord = lexicon.isCommonWord(baseTokenForCommonWordGuard(observedToken.normalized))
        let stylizedSingleTokenEntry = isStylizedSingleTokenEntry(best.entry)
        let observedHasRuntimePronunciation = lexicon.pronunciation(for: observedToken.normalized) != nil
        let hasStructuralContext = hasStructuralCommonWordBrandContext(
            tokenStart: start,
            tokenEndExclusive: end,
            tokens: tokens
        )
        let hasNounIntroducedTitlecaseContext = self.hasNounIntroducedTitlecaseContext(
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
        let hasAdjacentTitlecaseContext = hasAdjacentTitlecasePhraseContext(
            tokenIndex: start,
            totalTokens: tokens.count,
            tokens: tokens,
            text: text
        )
        let hasAdjacentTitlecaseListContext = self.hasAdjacentTitlecaseListContext(
            tokenIndex: start,
            totalTokens: tokens.count,
            tokens: tokens,
            text: text
        )
        let hasUnknownWordStylizedFallbackEvidence =
            !observedHasRuntimePronunciation
            && allowStylizedFallbackBySurface
            && hasStrongStylizedFallbackPhoneticEvidence(
                observed: observedToken.normalized,
                candidate: candidateToken,
                observedPhonetic: observedToken.phonetic,
                candidatePhonetic: candidatePhonetic,
                textSimilarity: textSimilarity
            )

        var adjustedThreshold = effectiveThreshold
        var requiresPeerSupport = false
        var requiresPeerSupportForTitlecaseKnownWord = false

        if observedHasRuntimePronunciation,
           isCommonWord,
           !stylizedSingleTokenEntry,
           textSimilarity < StandardEvaluationPolicy.peerSupportSimilarityMaximum {
            // Guard risky common-word -> brand hops unless corroborated by another
            // independent replacement in the same utterance.
            requiresPeerSupport = true
        }

        if stylizedSingleTokenEntry,
           hasAdjacentTitlecaseContext,
           !hasStrongStylizedTextEvidence(
               observed: observedToken.normalized,
               candidate: candidateToken,
               textSimilarity: textSimilarity
           ),
           !hasUnknownWordStylizedFallbackEvidence {
            if !hasAdjacentTitlecaseListContext {
                stats.rejectedLowScore += 1
                return nil
            }
        }

        if observedHasRuntimePronunciation,
           isTitlecaseToken(observedToken),
           observedToken.normalized.count >= candidateToken.count,
           !hasNounIntroducedTitlecaseContext,
           !hasAdjacentTitlecaseListContext,
           textSimilarity < StandardEvaluationPolicy.titlecaseKnownWordSurfaceMinimum {
            requiresPeerSupport = true
            requiresPeerSupportForTitlecaseKnownWord = true
        }

        if stylizedSingleTokenEntry,
           !allowStylizedFallbackBySurface,
           !hasStructuralContext,
           textSimilarity < StandardEvaluationPolicy.stylizedSurfaceSimilarityMinimum {
            stats.rejectedLowScore += 1
            return nil
        }

        if stylizedSingleTokenEntry,
           !hasStylizedLongPrefixTailGuardEvidence(
                observed: selection.observedNormalized,
                candidate: candidateToken
           ) {
            stats.rejectedLowScore += 1
            return nil
        }

        if isCommonWord {
            if hasStructuralContext {
                adjustedThreshold = min(
                    adjustedThreshold,
                    StandardEvaluationPolicy.commonWordStructuralContextThreshold
                )
            }
            if hasAttributionPrepositionContext {
                adjustedThreshold = min(
                    adjustedThreshold,
                    StandardEvaluationPolicy.commonWordAttributionContextThreshold
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
                adjustedThreshold = min(adjustedThreshold, StandardEvaluationPolicy.stylizedStrongTextThreshold)
            } else if textSimilarity >= StandardEvaluationPolicy.stylizedSurfaceSimilarityMinimum {
                // Runtime lexicon coverage can vary; keep stylized single-token
                // brand corrections resilient when text evidence is strong.
                adjustedThreshold = min(adjustedThreshold, StandardEvaluationPolicy.stylizedStrongSurfaceThreshold)
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
                adjustedThreshold = min(adjustedThreshold, StandardEvaluationPolicy.stylizedStrongFallbackThreshold)
            } else if hasModerateStylizedFallbackPhoneticEvidence(
                observed: observedToken.normalized,
                candidate: candidateToken,
                observedPhonetic: observedToken.phonetic,
                candidatePhonetic: candidatePhonetic,
                textSimilarity: textSimilarity
            ), allowStylizedFallbackBySurface {
                // Allow an additional conservative lane for all-caps/near-miss
                // stylized tokens that preserve start anchoring and fallback shape.
                adjustedThreshold = min(adjustedThreshold, StandardEvaluationPolicy.stylizedModerateFallbackThreshold)
            }
        }

        // Without hinting, strict length and text/phonetic agreement can lower
        // the threshold for proper-noun-like single tokens.
        if !isCommonWord,
           observedToken.normalized.count >= 5,
           candidateToken.count >= 5,
           max(textSimilarity, phoneticSimilarity) >= StandardEvaluationPolicy.properNounSimilarityMinimum,
           ((0.6 * textSimilarity) + (0.4 * phoneticSimilarity)) >= StandardEvaluationPolicy.properNounBlendedSimilarityMinimum {
            adjustedThreshold = min(adjustedThreshold, StandardEvaluationPolicy.properNounThreshold)
        }

        return StandardSingleTokenEvaluation(
            effectiveThreshold: adjustedThreshold,
            requiresPeerSupport: requiresPeerSupport,
            requiresPeerSupportForTitlecaseKnownWord: requiresPeerSupportForTitlecaseKnownWord,
            candidatePhonetic: candidatePhonetic
        )
    }

    func requiresPeerSupportAfterStandardCommonWordGuard(
        start: Int,
        tokens: [Token],
        window: [Token],
        candidate: Candidate,
        candidatePhonetic: String,
        requiresPeerSupport: Bool,
        requiresPeerSupportForTitlecaseKnownWord: Bool,
        stats: inout DebugStats
    ) -> CommonWordGuardOutcome {
        let end = start + 1
        guard lexicon.isCommonWord(baseTokenForCommonWordGuard(window[0].normalized)) else {
            return .allowed(requiresPeerSupport: requiresPeerSupport)
        }

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
            isStylizedSingleTokenEntry(candidate.entry)
            && !allowStylizedBySurface
        let hasAttributionPrepositionContext = hasAttributionLikePrepositionContext(tokenStart: start, tokens: tokens)
        if !isStylizedSingleTokenEntry(candidate.entry),
           !hasStructuralContext,
           !hasAttributionPrepositionContext {
            stats.rejectedCommonWord += 1
            return .rejected
        }

        var adjustedRequiresPeerSupport = requiresPeerSupport
        let stylizedStructuralBypass =
            stylizedCommonWordWithoutSurfaceEvidence
            && hasStructuralContext
            && candidate.score.final >= StandardEvaluationPolicy.commonWordStructuralBypassMinimum
        if stylizedCommonWordWithoutSurfaceEvidence {
            // Common prose tokens that only match via fallback phonetics should
            // need independent clause-local evidence before replacing.
            adjustedRequiresPeerSupport = !stylizedStructuralBypass
        }
        var stylizedBrandBypass =
            isStylizedSingleTokenEntry(candidate.entry)
            && allowStylizedBySurface
            && candidate.score.final >= StandardEvaluationPolicy.commonWordStylizedBypassMinimum
        stylizedBrandBypass = stylizedBrandBypass || stylizedStructuralBypass
        if !stylizedBrandBypass,
           isStylizedSingleTokenEntry(candidate.entry),
           allowStylizedBySurface,
           let candidateToken = candidate.entry.tokens.first {
            let textSimilarity = scorer.similarity(lhs: window[0].normalized, rhs: candidateToken)
            if hasStrongStylizedFallbackPhoneticEvidence(
                observed: window[0].normalized,
                candidate: candidateToken,
                observedPhonetic: window[0].phonetic,
                candidatePhonetic: candidatePhonetic,
                textSimilarity: textSimilarity
            ), candidate.score.final >= StandardEvaluationPolicy.commonWordFallbackBypassMinimum {
                stylizedBrandBypass = true
            }
        }
        if !stylizedBrandBypass,
           candidate.score.final < scorer.commonWordOverrideThreshold {
            if hasStructuralContext {
                if !requiresPeerSupportForTitlecaseKnownWord {
                    adjustedRequiresPeerSupport = false
                }
            } else if stylizedCommonWordWithoutSurfaceEvidence || hasAttributionPrepositionContext {
                adjustedRequiresPeerSupport = true
            } else if !adjustedRequiresPeerSupport {
                stats.rejectedCommonWord += 1
                return .rejected
            }
        }
        return .allowed(requiresPeerSupport: adjustedRequiresPeerSupport)
    }

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
        let rightIsLowerAlphabetic = !right.isEmpty && right.unicodeScalars.allSatisfy {
            $0.isASCII && $0.properties.isLowercase
        }
        let leftIsVerb = leftToken.lexicalClass == .verb
        let rightIsVerbLike = rightToken.lexicalClass == .verb || rightToken.lexicalClass == .adjective

        return self.hasNounIntroducedTitlecaseContext(
            tokenStart: tokenStart,
            tokenEndExclusive: tokenEndExclusive,
            tokens: tokens
        )
            || (left.count <= StandardEvaluationPolicy.structuralLeftContextMaximumLength
                && leftIsVerb
                && rightIsLowerAlphabetic
                && right.count >= StandardEvaluationPolicy.structuralRightContextMinimumLength
                && rightIsVerbLike)
    }

    private func hasNounIntroducedTitlecaseContext(
        tokenStart: Int,
        tokenEndExclusive: Int,
        tokens: [Token]
    ) -> Bool {
        guard tokenStart > 0, tokenEndExclusive < tokens.count else { return false }
        return tokens[tokenStart - 1].lexicalClass == .noun
            && isTitlecaseToken(tokens[tokenStart])
            && tokens[tokenEndExclusive].lexicalClass == .adverb
    }
}
