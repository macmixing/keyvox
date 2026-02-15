import Foundation

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
        guard window[0].normalized.count >= minimumSplitTokenLength,
              window[1].normalized.count >= minimumSplitTokenLength else {
            stats.rejectedShortToken += 1
            return nil
        }

        let forms = splitJoinForms(from: window)
        guard !forms.isEmpty else {
            stats.rejectedLowScore += 1
            return nil
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
                let adjustedScore = ReplacementScore(
                    text: score.text,
                    phonetic: score.phonetic,
                    context: score.context,
                    final: min(1.0, score.final + possessiveBonus(for: form.replacementSuffix))
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
}
