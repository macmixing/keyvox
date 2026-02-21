import Foundation

private enum ThreeTokenEvaluationConstants {
    static let minimumObservedLastStemLength = 4

    static let possessiveRecoveryTailTextMinimum = 0.34
    static let standardTailTextMinimum = 0.56
    static let possessiveRecoveryTailPhoneticMinimum = 0.38
    static let standardTailPhoneticMinimum = 0.60

    static let anchorBonus = 0.10
    static let strongTailTextMinimum = 0.68
    static let strongTailPhoneticMinimum = 0.72
    static let strongTailBonus = 0.08
    static let weakTailBonus = 0.04
    static let middleInitialAcceptanceThreshold = 0.58

    static let minimumObservedMidLength = 3
    static let minimumObservedTailLength = 2
    static let shortObservedFirstMaximumLength = 3
    static let compressedFirstTextMinimum = 0.20
    static let compressedFirstPhoneticMinimum = 0.42
    static let compressedCombinedTextMinimum = 0.66
    static let compressedCombinedPhoneticMinimum = 0.68
    static let compressedTailSimilarityMinimum = 0.66
    static let compressedStrongCombinedTextMinimum = 0.76
    static let compressedStrongCombinedPhoneticMinimum = 0.78
    static let compressedBonusBase = 0.10
    static let compressedBonusStrong = 0.08
    static let compressedBonusWeak = 0.04
    static let compressedTailAcceptanceThreshold = 0.62
}

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
        guard observedLastStem.count >= ThreeTokenEvaluationConstants.minimumObservedLastStemLength else {
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
            let minimumTailTextSimilarity = requiresPossessiveRecovery
                ? ThreeTokenEvaluationConstants.possessiveRecoveryTailTextMinimum
                : ThreeTokenEvaluationConstants.standardTailTextMinimum
            let minimumTailPhoneticSimilarity = requiresPossessiveRecovery
                ? ThreeTokenEvaluationConstants.possessiveRecoveryTailPhoneticMinimum
                : ThreeTokenEvaluationConstants.standardTailPhoneticMinimum
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

            let anchorBonus = ThreeTokenEvaluationConstants.anchorBonus
            let tailBonus =
                (lastTextSimilarity >= ThreeTokenEvaluationConstants.strongTailTextMinimum
                 || lastPhoneticSimilarity >= ThreeTokenEvaluationConstants.strongTailPhoneticMinimum)
                ? ThreeTokenEvaluationConstants.strongTailBonus
                : ThreeTokenEvaluationConstants.weakTailBonus
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

        guard best.score.final >= ThreeTokenEvaluationConstants.middleInitialAcceptanceThreshold else {
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

        guard observedMid.count >= ThreeTokenEvaluationConstants.minimumObservedMidLength,
              observedTail.count >= ThreeTokenEvaluationConstants.minimumObservedTailLength else { return nil }
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
                || (observedFirst.count <= ThreeTokenEvaluationConstants.shortObservedFirstMaximumLength
                    && !lexicon.isCommonWord(baseTokenForCommonWordGuard(observedFirst))) else { continue }

            let firstTextSimilarity = scorer.similarity(lhs: observedFirst, rhs: candidateFirst)
            let firstPhoneticSimilarity = scorer.similarity(
                lhs: window[0].phonetic,
                rhs: encoder.scoringSignature(for: candidateFirst, lexicon: lexicon)
            )
            guard firstTextSimilarity >= ThreeTokenEvaluationConstants.compressedFirstTextMinimum
                || firstPhoneticSimilarity >= ThreeTokenEvaluationConstants.compressedFirstPhoneticMinimum else { continue }

            let combinedTextSimilarity = scorer.similarity(lhs: observedCombined, rhs: candidateSecond)
            let combinedPhoneticSimilarity = scorer.similarity(
                lhs: observedCombinedPhonetic,
                rhs: encoder.scoringSignature(for: candidateSecond, lexicon: lexicon)
            )
            guard combinedTextSimilarity >= ThreeTokenEvaluationConstants.compressedCombinedTextMinimum
                || combinedPhoneticSimilarity >= ThreeTokenEvaluationConstants.compressedCombinedPhoneticMinimum else { continue }

            let candidateTail = String(candidateSecond.suffix(observedTail.count))
            let tailSimilarity = scorer.similarity(lhs: observedTail, rhs: candidateTail)
            guard tailSimilarity >= ThreeTokenEvaluationConstants.compressedTailSimilarityMinimum else { continue }

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

            let bonus = ThreeTokenEvaluationConstants.compressedBonusBase
                + ((combinedTextSimilarity >= ThreeTokenEvaluationConstants.compressedStrongCombinedTextMinimum
                    || combinedPhoneticSimilarity >= ThreeTokenEvaluationConstants.compressedStrongCombinedPhoneticMinimum)
                   ? ThreeTokenEvaluationConstants.compressedBonusStrong
                   : ThreeTokenEvaluationConstants.compressedBonusWeak)
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

        guard best.score.final >= ThreeTokenEvaluationConstants.compressedTailAcceptanceThreshold else {
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
