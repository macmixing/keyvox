import Foundation

extension DictionaryMatcher {
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
        guard let selection = selectBestStandardCandidate(
            start: start,
            tokenCount: tokenCount,
            tokens: tokens,
            candidates: candidates,
            window: window,
            observedNormalized: observedNormalized,
            observedPhonetic: observedPhonetic
        ) else {
            return nil
        }
        let best = selection.candidate

        if shouldRejectMismatchedSpelledUppercaseSequence(window: window, candidate: best.entry) {
            stats.rejectedLowScore += 1
            return nil
        }

        let exactMatch = observedNormalized == best.entry.normalizedPhrase
        if tokenCount == 1,
           window[0].normalized.count < StandardEvaluationPolicy.minimumSingleTokenLength,
           !exactMatch {
            stats.rejectedShortToken += 1
            return nil
        }

        let baseEffectiveThreshold = standardEffectiveThreshold(
            tokenCount: tokenCount,
            candidate: best
        )
        let singleTokenEvaluation: StandardSingleTokenEvaluation?
        let effectiveThreshold: Double
        var requiresPeerSupport = false

        if tokenCount == 1 {
            guard let evaluation = evaluateStandardSingleToken(
                start: start,
                tokens: tokens,
                text: text,
                window: window,
                selection: selection,
                effectiveThreshold: baseEffectiveThreshold,
                stats: &stats
            ) else {
                return nil
            }
            singleTokenEvaluation = evaluation
            effectiveThreshold = evaluation.effectiveThreshold
        } else if tokenCount == 2,
                  best.entry.tokens.count == 2 {
            singleTokenEvaluation = nil
            effectiveThreshold = adjustedStandardThresholdForTwoTokenCandidate(
                window: window,
                candidate: best.entry,
                effectiveThreshold: baseEffectiveThreshold
            )
        } else {
            singleTokenEvaluation = nil
            effectiveThreshold = baseEffectiveThreshold
        }

        guard best.score.final >= effectiveThreshold else {
            stats.rejectedLowScore += 1
            return nil
        }

        if selection.secondBestScore > 0,
           (best.score.final - selection.secondBestScore) < scorer.ambiguityMargin {
            stats.rejectedAmbiguity += 1
            return nil
        }

        if let singleTokenEvaluation {
            let commonWordGuardOutcome = requiresPeerSupportAfterStandardCommonWordGuard(
                start: start,
                tokens: tokens,
                window: window,
                candidate: best,
                candidatePhonetic: singleTokenEvaluation.candidatePhonetic,
                requiresPeerSupport: singleTokenEvaluation.requiresPeerSupport,
                requiresPeerSupportForTitlecaseKnownWord: singleTokenEvaluation.requiresPeerSupportForTitlecaseKnownWord,
                stats: &stats
            )
            switch commonWordGuardOutcome {
            case .rejected:
                return nil
            case .allowed(let adjustedRequiresPeerSupport):
                requiresPeerSupport = adjustedRequiresPeerSupport
            }
        }

        var tokenEndExclusive = end
        var range = combinedRange(from: window)
        if shouldConsumeSplitTailToken(
            window: window,
            candidate: best.entry,
            nextToken: end < tokens.count ? tokens[end] : nil
        ) {
            tokenEndExclusive = end + 1
            range = combinedRange(from: Array(tokens[start..<tokenEndExclusive]))
        }

        var replacementSuffix = best.replacementSuffix
        if selection.usesCandidateRelativeTrailingForm,
           let candidateToken = best.entry.tokens.first {
            let nextToken = end < tokens.count ? tokens[end] : nil
            if shouldInferPossessiveSuffix(
                observed: window[0].normalized,
                observedPhonetic: window[0].phonetic,
                candidate: candidateToken,
                nextToken: nextToken,
                hasCandidateRelativeTrailingEvidence: true
            ) {
                replacementSuffix = "'s"
            }
        } else if replacementSuffix.isEmpty,
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
