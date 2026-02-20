import Foundation

private enum MergedTokenEvaluationConstants {
    static let headSimilarityMinimum = 0.40
    static let exactTailBonus = 0.10
    static let abbreviatedHeadMaximumLength = 3
    static let abbreviatedHeadTailBonus = 0.14
    static let standardTailBonus = 0.06
    static let acceptanceThreshold = 0.72
}

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
                let mergedCandidatePhonetic = encoder.scoringSignature(for: mergedCandidate, lexicon: lexicon)
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
                let observedHeadPhonetic = encoder.scoringSignature(for: observedHead, lexicon: lexicon)
                let candidateHeadPhonetic = encoder.scoringSignature(for: candidateHead, lexicon: lexicon)
                let headTextSimilarity = scorer.similarity(lhs: observedHead, rhs: candidateHead)
                let headPhoneticSimilarity = scorer.similarity(lhs: observedHeadPhonetic, rhs: candidateHeadPhonetic)

                // Keep this path conservative: only allow merged-token expansion
                // when the non-tail prefix is still reasonably similar.
                guard max(headTextSimilarity, headPhoneticSimilarity) >= MergedTokenEvaluationConstants.headSimilarityMinimum else { continue }

                let tailExactBonus: Double
                if observed.normalized == mergedCandidate {
                    tailExactBonus = MergedTokenEvaluationConstants.exactTailBonus
                } else if observedHead.count <= MergedTokenEvaluationConstants.abbreviatedHeadMaximumLength {
                    // Allow abbreviated merged heads like "mr" -> "mister" when
                    // the trailing token anchor matches exactly.
                    tailExactBonus = MergedTokenEvaluationConstants.abbreviatedHeadTailBonus
                } else {
                    tailExactBonus = MergedTokenEvaluationConstants.standardTailBonus
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

        let threshold = MergedTokenEvaluationConstants.acceptanceThreshold
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
}
