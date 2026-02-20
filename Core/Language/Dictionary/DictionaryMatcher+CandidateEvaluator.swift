import Foundation

extension DictionaryMatcher {
    func proposeMergedTokenReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        guard start < tokens.count else { return nil }
        let observed = tokens[start]
        guard observed.normalized.count >= minimumSplitTokenLength else { return nil }

        stats.attempted += 1

        var best: Candidate?
        var secondBestScore = 0.0

        for tokenCount in 2...4 {
            guard let candidates = entriesByTokenCount[tokenCount], !candidates.isEmpty else { continue }
            for candidate in candidates {
                guard let tail = candidate.tokens.last else { continue }
                guard observed.normalized.count > tail.count, observed.normalized.hasSuffix(tail) else { continue }

                let mergedCandidate = candidate.tokens.joined()
                let mergedCandidatePhonetic = encoder.signature(for: mergedCandidate, lexicon: lexicon)
                let baseScore = scorer.score(
                    observedText: observed.normalized,
                    observedPhonetic: observed.phonetic,
                    candidateText: mergedCandidate,
                    candidatePhonetic: mergedCandidatePhonetic,
                    previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                    nextToken: start + 1 < tokens.count ? tokens[start + 1].normalized : nil
                )

                let observedHead = String(observed.normalized.dropLast(tail.count))
                let candidateHead = String(mergedCandidate.dropLast(tail.count))
                let observedHeadPhonetic = encoder.signature(for: observedHead, lexicon: lexicon)
                let candidateHeadPhonetic = encoder.signature(for: candidateHead, lexicon: lexicon)
                let headTextSimilarity = scorer.similarity(lhs: observedHead, rhs: candidateHead)
                let headPhoneticSimilarity = scorer.similarity(lhs: observedHeadPhonetic, rhs: candidateHeadPhonetic)

                // Keep this path conservative: only allow merged-token expansion
                // when the non-tail prefix is still reasonably similar.
                guard max(headTextSimilarity, headPhoneticSimilarity) >= 0.40 else { continue }

                let tailExactBonus: Double
                if observed.normalized == mergedCandidate {
                    tailExactBonus = 0.10
                } else if observedHead.count <= 3 {
                    // Allow abbreviated merged heads like "mr" -> "mister" when
                    // the trailing token anchor matches exactly.
                    tailExactBonus = 0.14
                } else {
                    tailExactBonus = 0.06
                }
                let score = ReplacementScore(
                    text: baseScore.text,
                    phonetic: baseScore.phonetic,
                    context: baseScore.context,
                    final: min(1.0, baseScore.final + tailExactBonus)
                )

                if let currentBest = best {
                    if score.final > currentBest.score.final {
                        secondBestScore = currentBest.score.final
                        best = Candidate(entry: candidate, score: score, replacementSuffix: "")
                    } else if score.final > secondBestScore {
                        secondBestScore = score.final
                    }
                } else {
                    best = Candidate(entry: candidate, score: score, replacementSuffix: "")
                }
            }
        }

        guard let best else {
            return nil
        }

        let threshold = 0.72
        guard best.score.final >= threshold else {
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

        let range = observed.range
        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase
        if observedRaw == replacementText {
            return nil
        }

        return ProposedReplacement(
            tokenStart: start,
            tokenEndExclusive: start + 1,
            range: range,
            replacement: replacementText,
            score: best.score.final
        )
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
        var effectiveThreshold: Double
        if tokenCount == 1, best.replacementSuffix == "'s" {
            // Possessive tails add noise; allow a slightly lower gate while keeping
            // common-word and ambiguity guards intact.
            effectiveThreshold = max(0.82, threshold - 0.08)
        } else {
            effectiveThreshold = threshold
        }

        if tokenCount == 1 {
            let observedToken = window[0]
            let candidateToken = best.entry.tokens[0]
            let candidatePhonetic = encoder.signature(for: candidateToken, lexicon: lexicon)
            let textSimilarity = scorer.similarity(lhs: observedToken.normalized, rhs: candidateToken)
            let phoneticSimilarity = scorer.similarity(lhs: observedToken.phonetic, rhs: candidatePhonetic)
            let isCommonWord = lexicon.isCommonWord(baseTokenForCommonWordGuard(observedToken.normalized))
            let stylizedSingleTokenEntry = isStylizedSingleTokenEntry(best.entry)

            if !isCommonWord,
               stylizedSingleTokenEntry,
               observedToken.normalized.count >= 5,
               candidateToken.count >= 5 {
                if hasStrongStylizedTextEvidence(
                    observed: observedToken.normalized,
                    candidate: candidateToken,
                    textSimilarity: textSimilarity
                ) {
                    // Runtime lexicon pronunciations can disagree on letter-level
                    // edits (e.g. one-character brand near-misses). If stylized
                    // text evidence is very strong, avoid over-penalizing phonetics.
                    effectiveThreshold = min(effectiveThreshold, 0.50)
                } else if textSimilarity >= 0.82 {
                    // Runtime lexicon coverage can vary; keep stylized single-token
                    // brand corrections resilient when text evidence is strong.
                    effectiveThreshold = min(effectiveThreshold, 0.72)
                }
            }

            // Generic hardening for proper-noun-like single tokens when hinting is absent:
            // require longer non-common tokens plus strong text/phonetic agreement.
            if !isCommonWord,
               observedToken.normalized.count >= 5,
               candidateToken.count >= 5,
               max(textSimilarity, phoneticSimilarity) >= 0.80,
               ((0.6 * textSimilarity) + (0.4 * phoneticSimilarity)) >= 0.74 {
                effectiveThreshold = min(effectiveThreshold, 0.78)
            }
        } else if tokenCount == 2,
                  best.entry.tokens.count == 2 {
            if hasStrongAnchoredTwoTokenEvidence(window: window, candidate: best.entry) {
                // Runtime pronunciations for proper nouns can be sparse. When the first
                // token anchors exactly and the second token is strongly similar, allow
                // the match through a slightly lower gate.
                effectiveThreshold = min(effectiveThreshold, 0.72)
            } else if hasModerateAnchoredTwoTokenEvidence(window: window, candidate: best.entry) {
                // Some near-miss surname variants are close in spelling shape but can
                // diverge in runtime lexicon phonetics. Keep this fallback conservative
                // with exact first-token anchoring and non-common long-tail requirements.
                effectiveThreshold = min(effectiveThreshold, 0.55)
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
            let stylizedBrandBypass =
                isStylizedSingleTokenEntry(best.entry)
                && best.score.final >= 0.82
            if !stylizedBrandBypass,
               best.score.final < scorer.commonWordOverrideThreshold {
                stats.rejectedCommonWord += 1
                return nil
            }
        }

        var tokenEndExclusive = end
        var range = combinedRange(from: window)
        if shouldConsumeSplitTailToken(window: window, candidate: best.entry, nextToken: end < tokens.count ? tokens[end] : nil) {
            tokenEndExclusive = end + 1
            range = combinedRange(from: Array(tokens[start..<tokenEndExclusive]))
        }

        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase + best.replacementSuffix

        if observedRaw == replacementText {
            return nil
        }

        return ProposedReplacement(
            tokenStart: start,
            tokenEndExclusive: tokenEndExclusive,
            range: range,
            replacement: replacementText,
            score: best.score.final
        )
    }

    private func shouldConsumeSplitTailToken(
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

    func isStylizedSingleTokenEntry(_ entry: CompiledEntry) -> Bool {
        guard entry.tokens.count == 1 else { return false }
        guard !entry.phrase.contains(" ") else { return false }
        let firstScalar = entry.phrase.unicodeScalars.first
        return entry.phrase.unicodeScalars.contains { scalar in
            guard scalar.properties.isUppercase else { return false }
            return scalar != firstScalar
        }
    }

    private func hasStrongStylizedTextEvidence(
        observed: String,
        candidate: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= 0.83 else { return false }
        guard observed.unicodeScalars.first == candidate.unicodeScalars.first else { return false }
        guard observed.unicodeScalars.last == candidate.unicodeScalars.last else { return false }
        return true
    }

    private func hasStrongAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
        guard window.count == 2, candidate.tokens.count == 2 else { return false }
        let observedFirst = window[0].normalized
        let observedSecond = window[1].normalized
        let candidateFirst = candidate.tokens[0]
        let candidateSecond = candidate.tokens[1]

        guard observedFirst == candidateFirst else { return false }
        guard observedSecond.count >= 5, candidateSecond.count >= 5 else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }

        let candidateSecondPhonetic = encoder.signature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        return secondTextSimilarity >= 0.70 || secondPhoneticSimilarity >= 0.72
    }

    private func hasModerateAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
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

        let candidateSecondPhonetic = encoder.signature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        // Favor text shape for this fallback because runtime lexicon coverage can
        // under-represent proper-name variants. Keep phonetic as an alternate path.
        return secondTextSimilarity >= 0.60 || secondPhoneticSimilarity >= 0.68
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
