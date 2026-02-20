import Foundation

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
        guard observedSecond.count >= 5, candidateSecond.count >= 5 else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }

        let candidateSecondPhonetic = encoder.scoringSignature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        return secondTextSimilarity >= 0.70 || secondPhoneticSimilarity >= 0.72
    }

    func hasModerateAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
        guard window.count == 2, candidate.tokens.count == 2 else { return false }
        let observedFirst = window[0].normalized
        let observedSecond = window[1].normalized
        let candidateFirst = candidate.tokens[0]
        let candidateSecond = candidate.tokens[1]

        guard observedFirst == candidateFirst else { return false }
        guard observedSecond.count >= 6, candidateSecond.count >= 6 else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }
        guard observedSecond.first == candidateSecond.first else { return false }
        guard observedSecond.last == candidateSecond.last else { return false }

        let candidateSecondPhonetic = encoder.scoringSignature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        // Favor text shape for this fallback because runtime lexicon coverage can
        // under-represent proper-name variants. Keep phonetic as an alternate path.
        return secondTextSimilarity >= 0.60 || secondPhoneticSimilarity >= 0.68
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
            let blendedScore = (0.55 * textScore) + (0.45 * phoneticScore)

            if textScore == 1.0 {
                exactMatches += 1
                if index == 0 {
                    firstTokenExact = true
                }
            }

            if textScore >= 0.78 || phoneticScore >= 0.78 || blendedScore >= 0.78 {
                strongMatches += 1
            }
        }

        // Name-like two-token phrases: "Dom Espicito" -> "Dom Esposito"
        if window.count == 2, firstTokenExact {
            let textTail = scorer.similarity(lhs: window[1].normalized, rhs: candidate.tokens[1])
            let phoneticTail = scorer.similarity(lhs: window[1].phonetic, rhs: candidatePhonetics[1])
            if textTail >= 0.70 || phoneticTail >= 0.72 {
                return 0.12
            }
            if textTail >= 0.60 || phoneticTail >= 0.68 {
                return 0.08
            }
        }

        if firstTokenExact && strongMatches == window.count {
            return 0.08
        }

        if exactMatches >= 1 && strongMatches == window.count {
            return 0.06
        }

        if strongMatches == window.count {
            return 0.04
        }

        return 0
    }
}
