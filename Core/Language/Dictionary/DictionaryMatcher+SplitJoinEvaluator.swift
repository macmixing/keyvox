import Foundation

extension DictionaryMatcher {
    private static let domainLabelTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        // Generic DNS label shape (no hardcoded TLD list).
        pattern: #"(?i)^[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?$"#,
        options: []
    )

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

        let containsShortToken =
            window[0].normalized.count < minimumSplitTokenLength
            || window[1].normalized.count < minimumSplitTokenLength
        if containsShortToken {
            let exactJoinedCandidates = Set(oneTokenCandidates.map(\.normalizedPhrase))
            let hasExactJoinCandidate = forms.contains { form in
                exactJoinedCandidates.contains(form.normalized)
            }
            guard hasExactJoinCandidate else {
                stats.rejectedShortToken += 1
                return nil
            }
        }

        var best: Candidate?
        var secondBestScore = 0.0

        for candidate in oneTokenCandidates {
            let candidateToken = candidate.tokens[0]
            let candidateIsCommonWord = lexicon.isCommonWord(candidateToken)

            for form in forms {
                // Only non-common dictionary entries can use plural-tail singularization.
                if form.singularizedSecondToken && candidateIsCommonWord {
                    continue
                }

                let observedPhonetic = encoder.signature(for: form.normalized, lexicon: lexicon)
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
                    (form.replacementSuffix == "'s" && isStylizedSingleTokenEntry(candidate)) ? 0.04 : 0.0
                let anchoredStylizedBonus: Double
                if isStylizedSingleTokenEntry(candidate), candidateToken.hasPrefix(window[0].normalized) {
                    anchoredStylizedBonus = 0.06
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
        if isStylizedSingleTokenEntry(best.entry) {
            let candidateToken = best.entry.tokens[0]
            let similarity = splitJoinStylizedSimilarity(window: window, candidateToken: candidateToken)

            // Keep split-join strict by default, but allow stylized single-token
            // brand-like entries when both text and phonetic evidence are strong.
            if similarity.text >= 0.80, similarity.blended >= 0.70 {
                effectiveThreshold = min(effectiveThreshold, 0.74)
            } else if similarity.text >= 0.68, similarity.blended >= 0.62 {
                // Spoken split forms like "air act's" can still be a clean stylized
                // match when fallback phonetic shape is strong.
                effectiveThreshold = min(effectiveThreshold, 0.62)
            } else if isAnchoredStylizedSplitJoin(
                window: window,
                candidateToken: candidateToken
            ),
            similarity.text >= 0.40,
            similarity.phonetic >= 0.60,
            similarity.blended >= 0.48 {
                // Additional guarded lane for cases where Whisper splits a stylized
                // proper name into two spoken words (e.g., "air axe").
                effectiveThreshold = min(effectiveThreshold, 0.44)
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
        let replacementText = best.entry.phrase + replacementSuffix
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

    func splitJoinForms(from window: [Token]) -> [JoinedObservedForm] {
        guard window.count == 2 else { return [] }

        let first = window[0].normalized
        let second = window[1].normalized

        var forms: [JoinedObservedForm] = []
        var seen = Set<String>()

        let direct = first + second
        if !direct.isEmpty, seen.insert(direct).inserted {
            forms.append(
                JoinedObservedForm(
                    normalized: direct,
                    singularizedSecondToken: false,
                    replacementSuffix: ""
                )
            )
        }

        if second.hasSuffix("'s"), second.count > minimumSplitTokenLength {
            let stem = String(second.dropLast(2))
            if stem.count >= minimumSplitTokenLength {
                let possessiveJoin = first + stem
                if !possessiveJoin.isEmpty, seen.insert(possessiveJoin).inserted {
                    forms.append(
                        JoinedObservedForm(
                            normalized: possessiveJoin,
                            singularizedSecondToken: false,
                            replacementSuffix: "'s"
                        )
                    )
                }
            }
        }

        if second.hasSuffix("s"),
           !second.hasSuffix("'s"),
           !second.hasSuffix("s'"),
           second.count > minimumSplitTokenLength {
            let singularSecond = String(second.dropLast())
            if singularSecond.count >= minimumSplitTokenLength {
                let singularized = first + singularSecond
                if !singularized.isEmpty, seen.insert(singularized).inserted {
                    forms.append(
                        JoinedObservedForm(
                            normalized: singularized,
                            singularizedSecondToken: true,
                            replacementSuffix: ""
                        )
                    )
                }
            }
        }

        return forms
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
            let observedPhonetic = encoder.signature(for: form.normalized, lexicon: lexicon)
            let candidatePhonetic = encoder.signature(for: candidateToken, lexicon: lexicon)
            let runtimePhoneticSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
            let observedFallback = encoder.fallbackSignature(for: form.normalized)
            let candidateFallback = encoder.fallbackSignature(for: candidateToken)
            let fallbackPhoneticSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
            let phoneticSimilarity = max(runtimePhoneticSimilarity, fallbackPhoneticSimilarity)
            let blended = (0.6 * textSimilarity) + (0.4 * phoneticSimilarity)

            bestText = max(bestText, textSimilarity)
            bestPhonetic = max(bestPhonetic, phoneticSimilarity)
            bestBlended = max(bestBlended, blended)
        }

        return (bestText, bestPhonetic, bestBlended)
    }

    private func isAnchoredStylizedSplitJoin(window: [Token], candidateToken: String) -> Bool {
        guard window.count == 2 else { return false }
        let observedFirst = window[0].normalized
        guard observedFirst.count >= 3 else { return false }
        return candidateToken.hasPrefix(observedFirst)
    }

    private func shouldInferSplitJoinPossessiveSuffix(
        observedCombined: String,
        observedTail: String,
        candidate: String,
        nextToken: Token?
    ) -> Bool {
        guard nextToken != nil else { return false }
        guard !candidate.hasSuffix("s") else { return false }
        let hasPossessiveSoundEnding =
            hasPossessiveLikeEnding(observedCombined)
            || hasPossessiveLikeEnding(observedTail)
        return hasPossessiveSoundEnding
    }

    private func hasPossessiveLikeEnding(_ token: String) -> Bool {
        token.hasSuffix("s")
            || token.hasSuffix("x")
            || token.hasSuffix("z")
            || token.hasSuffix("ss")
            || token.hasSuffix("xe")
            || token.hasSuffix("ce")
            || token.hasSuffix("se")
            || token.hasSuffix("ze")
    }

    private func isLikelyDomainTokenSplit(window: [Token], text: String) -> Bool {
        guard window.count == 2 else { return false }
        let second = window[1].normalized
        guard second.count >= 2 else { return false }
        guard let regex = Self.domainLabelTokenRegex else { return false }
        let secondRange = NSRange(location: 0, length: (second as NSString).length)
        guard regex.firstMatch(in: second, options: [], range: secondRange) != nil else { return false }

        let nsText = text as NSString
        let dotBeforeSecond = window[1].range.location > 0
            && nsText.substring(with: NSRange(location: window[1].range.location - 1, length: 1)) == "."
        return dotBeforeSecond
    }
}
