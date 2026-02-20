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
        let observedForms = observedFormsForWindow(
            tokenCount: tokenCount,
            observedNormalized: observedNormalized,
            observedPhonetic: observedPhonetic
        )

        var best: Candidate?
        var secondBestScore = 0.0

        for candidate in candidates {
            for form in observedForms {
                let baseScore = scorer.score(
                    observedText: form.normalized,
                    observedPhonetic: form.phonetic,
                    candidateText: candidate.normalizedPhrase,
                    candidatePhonetic: candidate.phoneticPhrase,
                    previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                    nextToken: end < tokens.count ? tokens[end].normalized : nil
                )

                let boostedFinalScore = min(
                    1.0,
                    baseScore.final
                        + tokenAlignmentBoost(window: window, candidate: candidate)
                        + possessiveBonus(for: form.replacementSuffix)
                )
                let score = ReplacementScore(
                    text: baseScore.text,
                    phonetic: baseScore.phonetic,
                    context: baseScore.context,
                    final: boostedFinalScore
                )

                if let currentBest = best {
                    if score.final > currentBest.score.final {
                        secondBestScore = currentBest.score.final
                        best = Candidate(entry: candidate, score: score, replacementSuffix: form.replacementSuffix)
                    } else if score.final > secondBestScore {
                        secondBestScore = score.final
                    }
                } else {
                    best = Candidate(entry: candidate, score: score, replacementSuffix: form.replacementSuffix)
                }
            }
        }

        guard let best else { return nil }

        let exactMatch = observedNormalized == best.entry.normalizedPhrase

        if tokenCount == 1,
           window[0].normalized.count < 3,
           !exactMatch {
            stats.rejectedShortToken += 1
            return nil
        }

        let threshold = scorer.threshold(for: tokenCount)
        let effectiveThreshold: Double
        if tokenCount == 1, best.replacementSuffix == "'s" {
            // Possessive tails add noise; allow a slightly lower gate while keeping
            // common-word and ambiguity guards intact.
            effectiveThreshold = max(0.82, threshold - 0.08)
        } else {
            effectiveThreshold = threshold
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
           lexicon.isCommonWord(baseTokenForCommonWordGuard(window[0].normalized)),
           best.score.final < scorer.commonWordOverrideThreshold {
            stats.rejectedCommonWord += 1
            return nil
        }

        let range = combinedRange(from: window)
        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase + best.replacementSuffix

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

    func observedFormsForWindow(
        tokenCount: Int,
        observedNormalized: String,
        observedPhonetic: String
    ) -> [(normalized: String, phonetic: String, replacementSuffix: String)] {
        guard tokenCount == 1 else {
            return [(normalized: observedNormalized, phonetic: observedPhonetic, replacementSuffix: "")]
        }

        var forms: [(normalized: String, phonetic: String, replacementSuffix: String)] = [
            (normalized: observedNormalized, phonetic: observedPhonetic, replacementSuffix: "")
        ]
        var seen = Set<String>()
        seen.insert("\(observedNormalized)|")

        if observedNormalized.hasSuffix("'s"), observedNormalized.count > 3 {
            let stem = String(observedNormalized.dropLast(2))
            if stem.count >= 3 {
                let key = "\(stem)|'s"
                if seen.insert(key).inserted {
                    forms.append((
                        normalized: stem,
                        phonetic: encoder.signature(for: stem, lexicon: lexicon),
                        replacementSuffix: "'s"
                    ))
                }
            }
        }

        return forms
    }

    func baseTokenForCommonWordGuard(_ token: String) -> String {
        if token.hasSuffix("'s"), token.count > 3 {
            return String(token.dropLast(2))
        }

        return token
    }

    func possessiveBonus(for replacementSuffix: String) -> Double {
        replacementSuffix == "'s" ? possessiveStemScoreBoost : 0
    }

    func tokenAlignmentBoost(window: [Token], candidate: CompiledEntry) -> Double {
        guard window.count == candidate.tokens.count else { return 0 }
        guard !window.isEmpty else { return 0 }

        let candidatePhonetics = candidate.tokens.map { encoder.signature(for: $0, lexicon: lexicon) }
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
