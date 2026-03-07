import Foundation

private enum EvaluationEvidenceConstants {
    static let strongAnchoredMinimumTokenLength = 5
    static let strongAnchoredTextMinimum = 0.70
    static let strongAnchoredPhoneticMinimum = 0.72

    static let moderateAnchoredMinimumTokenLength = 6
    static let moderateAnchoredTextMinimum = 0.60
    static let moderateAnchoredPhoneticMinimum = 0.68

    static let blendedTextWeight = 0.55
    static let blendedPhoneticWeight = 0.45
    static let strongMatchMinimum = 0.78

    static let strongTailAlignmentBoost = 0.12
    static let moderateTailAlignmentBoost = 0.08
    static let firstTokenExactAlignmentBoost = 0.08
    static let exactAndStrongAlignmentBoost = 0.06
    static let allStrongAlignmentBoost = 0.04
}

extension DictionaryMatcher {
    func shouldConsumeSplitTailToken(
        window: [Token],
        candidate: CompiledEntry,
        nextToken: Token?
    ) -> Bool {
        guard window.count == candidate.tokens.count, window.count > 1 else { return false }
        guard let nextToken else { return false }

        // Guard a specific false-positive shape where Whisper splits the end of the
        // final dictionary token into a separate trailing token (e.g. "pinup ca").
        let sharedPrefixCount = window.count - 1
        for index in 0..<sharedPrefixCount where window[index].normalized != candidate.tokens[index] {
            return false
        }

        guard let observedLast = window.last?.normalized, let candidateLast = candidate.tokens.last else {
            return false
        }
        guard candidateLast.count > observedLast.count, candidateLast.hasPrefix(observedLast) else {
            return false
        }

        let trailingSuffix = String(candidateLast.dropFirst(observedLast.count))
        guard trailingSuffix.count >= 2 else { return false }
        return nextToken.normalized == trailingSuffix
    }

    func hasStrongAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
        guard window.count == 2, candidate.tokens.count == 2 else { return false }
        let observedFirst = window[0].normalized
        let observedSecond = window[1].normalized
        let candidateFirst = candidate.tokens[0]
        let candidateSecond = candidate.tokens[1]

        guard observedFirst == candidateFirst else { return false }
        guard observedSecond.count >= EvaluationEvidenceConstants.strongAnchoredMinimumTokenLength,
              candidateSecond.count >= EvaluationEvidenceConstants.strongAnchoredMinimumTokenLength else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }

        let candidateSecondPhonetic = encoder.scoringSignature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        return secondTextSimilarity >= EvaluationEvidenceConstants.strongAnchoredTextMinimum
            || secondPhoneticSimilarity >= EvaluationEvidenceConstants.strongAnchoredPhoneticMinimum
    }

    func hasModerateAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
        guard window.count == 2, candidate.tokens.count == 2 else { return false }
        let observedFirst = window[0].normalized
        let observedSecond = window[1].normalized
        let candidateFirst = candidate.tokens[0]
        let candidateSecond = candidate.tokens[1]

        guard observedFirst == candidateFirst else { return false }
        guard observedSecond.count >= EvaluationEvidenceConstants.moderateAnchoredMinimumTokenLength,
              candidateSecond.count >= EvaluationEvidenceConstants.moderateAnchoredMinimumTokenLength else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }
        guard observedSecond.first == candidateSecond.first else { return false }
        guard observedSecond.last == candidateSecond.last else { return false }

        let candidateSecondPhonetic = encoder.scoringSignature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        // Favor text shape for this fallback because runtime lexicon coverage can
        // under-represent proper-name variants. Keep phonetic as an alternate path.
        return secondTextSimilarity >= EvaluationEvidenceConstants.moderateAnchoredTextMinimum
            || secondPhoneticSimilarity >= EvaluationEvidenceConstants.moderateAnchoredPhoneticMinimum
    }

    func tokenAlignmentBoost(window: [Token], candidate: CompiledEntry) -> Double {
        guard window.count == candidate.tokens.count else { return 0 }
        guard !window.isEmpty else { return 0 }

        let candidatePhonetics = candidate.tokens.map { encoder.scoringSignature(for: $0, lexicon: lexicon) }
        var exactMatches = 0
        var strongMatches = 0
        var firstTokenExact = false

        for index in window.indices {
            let observedToken = window[index]
            let candidateToken = candidate.tokens[index]

            let textScore = scorer.similarity(lhs: observedToken.normalized, rhs: candidateToken)
            let phoneticScore = scorer.similarity(lhs: observedToken.phonetic, rhs: candidatePhonetics[index])
            let blendedScore = (EvaluationEvidenceConstants.blendedTextWeight * textScore)
                + (EvaluationEvidenceConstants.blendedPhoneticWeight * phoneticScore)

            if textScore == 1.0 {
                exactMatches += 1
                if index == 0 {
                    firstTokenExact = true
                }
            }

            if textScore >= EvaluationEvidenceConstants.strongMatchMinimum
                || phoneticScore >= EvaluationEvidenceConstants.strongMatchMinimum
                || blendedScore >= EvaluationEvidenceConstants.strongMatchMinimum {
                strongMatches += 1
            }
        }

        // Name-like two-token phrases: "Dom Espicito" -> "Dom Esposito"
        if window.count == 2, firstTokenExact {
            let textTail = scorer.similarity(lhs: window[1].normalized, rhs: candidate.tokens[1])
            let phoneticTail = scorer.similarity(lhs: window[1].phonetic, rhs: candidatePhonetics[1])
            if textTail >= EvaluationEvidenceConstants.strongAnchoredTextMinimum
                || phoneticTail >= EvaluationEvidenceConstants.strongAnchoredPhoneticMinimum {
                return EvaluationEvidenceConstants.strongTailAlignmentBoost
            }
            if textTail >= EvaluationEvidenceConstants.moderateAnchoredTextMinimum
                || phoneticTail >= EvaluationEvidenceConstants.moderateAnchoredPhoneticMinimum {
                return EvaluationEvidenceConstants.moderateTailAlignmentBoost
            }
        }

        if firstTokenExact && strongMatches == window.count {
            return EvaluationEvidenceConstants.firstTokenExactAlignmentBoost
        }

        if exactMatches >= 1 && strongMatches == window.count {
            return EvaluationEvidenceConstants.exactAndStrongAlignmentBoost
        }

        if strongMatches == window.count {
            return EvaluationEvidenceConstants.allStrongAlignmentBoost
        }

        return 0
    }
}
