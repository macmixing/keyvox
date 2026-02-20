import Foundation

extension DictionaryMatcher {
    func proposeMiddleInitialThreeTokenReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        let end = start + 3
        guard end <= tokens.count else { return nil }
        guard let twoTokenCandidates = entriesByTokenCount[2], !twoTokenCandidates.isEmpty else { return nil }

        let window = Array(tokens[start..<end])
        let observedFirst = window[0].normalized
        let observedMiddle = window[1].normalized
        let observedLastRaw = window[2].normalized

        guard observedMiddle.count == 1 else { return nil }
        stats.attempted += 1

        let possessive = normalizedPossessiveStem(for: observedLastRaw)
        let observedLastStem = possessive.stem
        guard observedLastStem.count >= 4 else {
            stats.rejectedLowScore += 1
            return nil
        }

        var best: Candidate?
        var secondBestScore = 0.0

        for candidate in twoTokenCandidates {
            guard candidate.tokens.count == 2 else { continue }
            let candidateFirst = candidate.tokens[0]
            let candidateLast = candidate.tokens[1]

            guard observedFirst == candidateFirst else { continue }
            guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateLast)) else { continue }

            let observedLastPhonetic = encoder.scoringSignature(for: observedLastStem, lexicon: lexicon)
            let candidateLastPhonetic = encoder.scoringSignature(for: candidateLast, lexicon: lexicon)
            let lastTextSimilarity = scorer.similarity(lhs: observedLastStem, rhs: candidateLast)
            let lastPhoneticSimilarity = scorer.similarity(lhs: observedLastPhonetic, rhs: candidateLastPhonetic)
            let requiresPossessiveRecovery = possessive.suffix == "'s"
            let minimumTailTextSimilarity = requiresPossessiveRecovery ? 0.34 : 0.56
            let minimumTailPhoneticSimilarity = requiresPossessiveRecovery ? 0.38 : 0.60
            guard lastTextSimilarity >= minimumTailTextSimilarity || lastPhoneticSimilarity >= minimumTailPhoneticSimilarity else {
                continue
            }

            let observedNormalized = "\(observedFirst) \(observedLastStem)"
            let observedPhonetic = encoder.scoringPhraseSignature(for: [observedFirst, observedLastStem], lexicon: lexicon)
            let baseScore = scorer.score(
                observedText: observedNormalized,
                observedPhonetic: observedPhonetic,
                candidateText: candidate.normalizedPhrase,
                candidatePhonetic: candidate.phoneticPhrase,
                previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                nextToken: end < tokens.count ? tokens[end].normalized : nil
            )

            let anchorBonus = 0.10
            let tailBonus = (lastTextSimilarity >= 0.68 || lastPhoneticSimilarity >= 0.72) ? 0.08 : 0.04
            let score = ReplacementScore(
                text: baseScore.text,
                phonetic: baseScore.phonetic,
                context: baseScore.context,
                final: min(1.0, baseScore.final + anchorBonus + tailBonus + possessiveBonus(for: possessive.suffix))
            )

            let replacementSuffix = resolvedPossessiveSuffix(basePhrase: candidate.phrase, desiredSuffix: possessive.suffix)
            if let currentBest = best {
                if score.final > currentBest.score.final {
                    secondBestScore = currentBest.score.final
                    best = Candidate(entry: candidate, score: score, replacementSuffix: replacementSuffix)
                } else if score.final > secondBestScore {
                    secondBestScore = score.final
                }
            } else {
                best = Candidate(entry: candidate, score: score, replacementSuffix: replacementSuffix)
            }
        }

        guard let best else {
            stats.rejectedLowScore += 1
            return nil
        }

        guard best.score.final >= 0.58 else {
            stats.rejectedLowScore += 1
            return nil
        }

        if secondBestScore > 0,
           (best.score.final - secondBestScore) < scorer.ambiguityMargin {
            stats.rejectedAmbiguity += 1
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

    func proposeCompressedTailThreeTokenReplacement(
        start: Int,
        tokens: [Token],
        text: String,
        stats: inout DebugStats
    ) -> ProposedReplacement? {
        let end = start + 3
        guard end <= tokens.count else { return nil }
        guard let twoTokenCandidates = entriesByTokenCount[2], !twoTokenCandidates.isEmpty else { return nil }

        let window = Array(tokens[start..<end])
        let observedFirst = window[0].normalized
        let observedMid = window[1].normalized
        let observedTail = window[2].normalized

        guard observedMid.count >= 3, observedTail.count >= 2 else { return nil }
        stats.attempted += 1

        let observedCombined = observedMid + observedTail
        let observedCombinedPhonetic = encoder.scoringSignature(for: observedCombined, lexicon: lexicon)

        var best: Candidate?
        var secondBestScore = 0.0

        for candidate in twoTokenCandidates {
            guard candidate.tokens.count == 2 else { continue }
            let candidateFirst = candidate.tokens[0]
            let candidateSecond = candidate.tokens[1]
            guard candidateSecond.count >= observedTail.count else { continue }
            guard observedFirst == candidateFirst
                || (observedFirst.count <= 3
                    && !lexicon.isCommonWord(baseTokenForCommonWordGuard(observedFirst))) else { continue }

            let firstTextSimilarity = scorer.similarity(lhs: observedFirst, rhs: candidateFirst)
            let firstPhoneticSimilarity = scorer.similarity(
                lhs: window[0].phonetic,
                rhs: encoder.scoringSignature(for: candidateFirst, lexicon: lexicon)
            )
            guard firstTextSimilarity >= 0.20 || firstPhoneticSimilarity >= 0.42 else { continue }

            let combinedTextSimilarity = scorer.similarity(lhs: observedCombined, rhs: candidateSecond)
            let combinedPhoneticSimilarity = scorer.similarity(
                lhs: observedCombinedPhonetic,
                rhs: encoder.scoringSignature(for: candidateSecond, lexicon: lexicon)
            )
            guard combinedTextSimilarity >= 0.66 || combinedPhoneticSimilarity >= 0.68 else { continue }

            let candidateTail = String(candidateSecond.suffix(observedTail.count))
            let tailSimilarity = scorer.similarity(lhs: observedTail, rhs: candidateTail)
            guard tailSimilarity >= 0.66 else { continue }

            let observedNormalized = "\(observedFirst) \(observedCombined)"
            let observedPhonetic = "\(window[0].phonetic) \(observedCombinedPhonetic)"
            let baseScore = scorer.score(
                observedText: observedNormalized,
                observedPhonetic: observedPhonetic,
                candidateText: candidate.normalizedPhrase,
                candidatePhonetic: candidate.phoneticPhrase,
                previousToken: start > 0 ? tokens[start - 1].normalized : nil,
                nextToken: end < tokens.count ? tokens[end].normalized : nil
            )

            let bonus = 0.10 + ((combinedTextSimilarity >= 0.76 || combinedPhoneticSimilarity >= 0.78) ? 0.08 : 0.04)
            let score = ReplacementScore(
                text: baseScore.text,
                phonetic: baseScore.phonetic,
                context: baseScore.context,
                final: min(1.0, baseScore.final + bonus)
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

        guard let best else {
            stats.rejectedLowScore += 1
            return nil
        }

        guard best.score.final >= 0.62 else {
            stats.rejectedLowScore += 1
            return nil
        }

        if secondBestScore > 0,
           (best.score.final - secondBestScore) < scorer.ambiguityMargin {
            stats.rejectedAmbiguity += 1
            return nil
        }

        let range = combinedRange(from: window)
        let observedRaw = (text as NSString).substring(with: range)
        let replacementText = best.entry.phrase
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
}
