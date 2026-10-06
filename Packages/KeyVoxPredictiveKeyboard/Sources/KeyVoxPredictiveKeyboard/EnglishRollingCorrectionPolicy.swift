import Foundation

public struct RollingCorrectionToken: Equatable, Sendable {
    public let original: String
    public let correctionResponse: PredictionResponse?
    public let protectsLiteral: Bool

    public init(
        original: String,
        correctionResponse: PredictionResponse?,
        protectsLiteral: Bool
    ) {
        self.original = original
        self.correctionResponse = correctionResponse
        self.protectsLiteral = protectsLiteral
    }
}

public struct RollingCorrectionSelection: Equatable, Sendable {
    public let replacementWords: [String]
    public let changedIndices: [Int]
    public let languageScoreImprovement: Double

    public init(
        replacementWords: [String],
        changedIndices: [Int],
        languageScoreImprovement: Double
    ) {
        self.replacementWords = replacementWords
        self.changedIndices = changedIndices
        self.languageScoreImprovement = languageScoreImprovement
    }
}

public enum EnglishRollingCorrectionPolicy {
    private struct Candidate {
        let word: String
        let probability: Double
        let isLiteral: Bool
    }

    private struct Path {
        let words: [String]
        let score: Double
        let changedIndices: [Int]
        let analyses: [WordLanguageAnalysis]
    }

    private struct AnalysisKey: Hashable {
        let word: String
        let previousWord: String
        let olderWord: String
    }

    private static let maximumWindowTokenCount = 6
    private static let maximumEditableLookback = 4
    private static let maximumCandidateCountPerToken = 5
    private static let maximumChangedTokenCount = 1
    private static let beamWidth = 48
    private static let validLiteralCandidateProbability = 0.02
    private static let strongValidLiteralCandidateProbability = 0.18
    private static let invalidLiteralMinimumCandidateProbability = 0.015
    private static let invalidLiteralReferenceProbability = 0.98
    private static let invalidLiteralProbabilityPenaltyScale = 2.0
    private static let strongInvalidCandidateProbability = 0.98
    private static let contextualInvalidCandidateProbability = 0.85
    private static let contextualInvalidActionProbability = 0.98
    private static let leadingInvalidCandidateActionProbability = 0.9
    private static let validLiteralImprovementThreshold = 3.0
    private static let lowConfidenceValidLiteralImprovementThreshold = 8.25
    private static let invalidLiteralImprovementThreshold = 2.35
    private static let competingPathMargin = 0.8

    public static func select(
        tokens suppliedTokens: [RollingCorrectionToken],
        precedingWords: [String],
        isProtectedWord: (String) -> Bool,
        analyze: (String, [String]) throws -> WordLanguageAnalysis
    ) throws -> RollingCorrectionSelection? {
        guard suppliedTokens.count >= 2 else { return nil }
        let tokens = Array(suppliedTokens.suffix(maximumWindowTokenCount))
        let normalizedPrecedingWords = precedingWords
            .prefix(2)
            .map(normalize)
        var analysisCache: [AnalysisKey: WordLanguageAnalysis] = [:]

        func resolvedAnalysis(
            word: String,
            previousWords: [String]
        ) throws -> WordLanguageAnalysis {
            let key = AnalysisKey(
                word: word,
                previousWord: previousWords.first ?? "",
                olderWord: previousWords.dropFirst().first ?? ""
            )
            if let cached = analysisCache[key] {
                return cached
            }
            let result = try analyze(word, previousWords)
            analysisCache[key] = result
            return result
        }

        let baseline = try scoreBaseline(
            tokens: tokens,
            precedingWords: normalizedPrecedingWords,
            analyze: resolvedAnalysis
        )
        let firstEditableIndex = max(
            0,
            tokens.count - 1 - maximumEditableLookback
        )
        var paths = [Path(words: [], score: 0, changedIndices: [], analyses: [])]

        for (index, token) in tokens.enumerated() {
            let candidates = candidates(
                for: token,
                isEditable: index >= firstEditableIndex && index < tokens.count - 1
            )
            var expanded: [Path] = []
            expanded.reserveCapacity(paths.count * candidates.count)

            for path in paths {
                let previousWords = pathPreviousWords(
                    path.words,
                    fallback: normalizedPrecedingWords
                )
                for candidate in candidates {
                    let analysis = try resolvedAnalysis(
                        word: candidate.word,
                        previousWords: previousWords
                    )
                    guard candidate.isLiteral
                            || analysis.wordIsValid
                            || isProtectedWord(candidate.word) else {
                        continue
                    }
                    let changedIndices = candidate.isLiteral
                        ? path.changedIndices
                        : path.changedIndices + [index]
                    guard changedIndices.count <= maximumChangedTokenCount else {
                        continue
                    }
                    expanded.append(
                        Path(
                            words: path.words + [candidate.word],
                            score: path.score
                                + transitionScore(analysis)
                                - editPenalty(for: candidate),
                            changedIndices: changedIndices,
                            analyses: path.analyses + [analysis]
                        )
                    )
                }
            }
            paths = Array(
                expanded
                    .sorted(by: pathRanksBefore)
                    .prefix(beamWidth)
            )
        }

        let eligible = paths
            .filter { path in
                path.changedIndices.isEmpty == false
                    && hasLaterContextEvidence(for: path)
            }
            .sorted(by: pathRanksBefore)
        guard let best = eligible.first else { return nil }

        let requiredImprovement = best.changedIndices.reduce(0.0) { result, index in
            let probability = tokens[index].correctionResponse?.suggestions.first {
                normalize($0.word) == best.words[index]
            }?.rankProbability ?? 0
            guard baseline.analyses[index].wordIsValid else {
                let spellingPenalty = invalidLiteralProbabilityPenaltyScale * max(
                    0,
                    log(
                        invalidLiteralReferenceProbability
                            / max(probability, 0.0001)
                    )
                )
                return result + invalidLiteralImprovementThreshold + spellingPenalty
            }
            return result + (probability >= strongValidLiteralCandidateProbability
                ? validLiteralImprovementThreshold
                : lowConfidenceValidLiteralImprovementThreshold)
        }
        let improvement = best.score - baseline.score
        guard improvement >= requiredImprovement else { return nil }
        guard hasSelectedSpellingSupport(
            path: best,
            tokens: tokens,
            baseline: baseline
        ) else { return nil }
        guard hasAutomaticActionSupportForLeadingInvalidCandidates(
            path: best,
            tokens: tokens,
            baseline: baseline
        ) else { return nil }
        if eligible.count > 1 {
            guard best.score - eligible[1].score >= competingPathMargin else {
                return nil
            }
        }
        return RollingCorrectionSelection(
            replacementWords: best.words,
            changedIndices: best.changedIndices,
            languageScoreImprovement: improvement
        )
    }

    private static func scoreBaseline(
        tokens: [RollingCorrectionToken],
        precedingWords: [String],
        analyze: (String, [String]) throws -> WordLanguageAnalysis
    ) throws -> Path {
        var words: [String] = []
        var analyses: [WordLanguageAnalysis] = []
        var score = 0.0
        for token in tokens {
            let word = normalize(token.original)
            let analysis = try analyze(
                word,
                pathPreviousWords(words, fallback: precedingWords)
            )
            words.append(word)
            analyses.append(analysis)
            score += transitionScore(analysis)
        }
        return Path(
            words: words,
            score: score,
            changedIndices: [],
            analyses: analyses
        )
    }

    private static func candidates(
        for token: RollingCorrectionToken,
        isEditable: Bool
    ) -> [Candidate] {
        let original = normalize(token.original)
        let literal = Candidate(word: original, probability: 1, isLiteral: true)
        guard isEditable,
              token.protectsLiteral == false,
              token.original == token.original.lowercased(),
              original.count >= 2,
              let response = token.correctionResponse else {
            return [literal]
        }

        var observed = Set([original])
        let alternatives = response.suggestions.compactMap { suggestion -> Candidate? in
            let word = normalize(suggestion.word)
            let carriesCorrectionEvidence: Bool
            if response.typedWordIsValid {
                carriesCorrectionEvidence = (
                    restoresOmittedApostrophe(
                        original: original,
                        candidate: word
                    ) || restoresSingleInternalCharacter(
                        original: original,
                        candidate: word
                    )
                ) && suggestion.rankProbability >= validLiteralCandidateProbability
            } else {
                carriesCorrectionEvidence = suggestion.rankProbability
                    >= invalidLiteralMinimumCandidateProbability
            }
            guard carriesCorrectionEvidence,
                  editDistance(original, word) == 1,
                  observed.insert(word).inserted else {
                return nil
            }
            return Candidate(
                word: word,
                probability: suggestion.rankProbability,
                isLiteral: false
            )
        }
        return [literal] + alternatives.prefix(maximumCandidateCountPerToken)
    }

    private static func restoresOmittedApostrophe(
        original: String,
        candidate: String
    ) -> Bool {
        original.contains("'") == false && candidate.contains("'")
    }

    private static func restoresSingleInternalCharacter(
        original: String,
        candidate: String
    ) -> Bool {
        let originalCharacters = Array(original)
        let candidateCharacters = Array(candidate)
        guard candidateCharacters.count == originalCharacters.count + 1 else {
            return false
        }
        var originalIndex = 0
        var insertionIndex: Int?
        for (candidateIndex, character) in candidateCharacters.enumerated() {
            if originalIndex < originalCharacters.count,
               character == originalCharacters[originalIndex] {
                originalIndex += 1
            } else if insertionIndex == nil {
                insertionIndex = candidateIndex
            } else {
                return false
            }
        }
        guard originalIndex == originalCharacters.count,
              let insertionIndex else {
            return false
        }
        return insertionIndex > 0 && insertionIndex < candidateCharacters.count - 1
    }

    private static func hasAutomaticActionSupportForLeadingInvalidCandidates(
        path: Path,
        tokens: [RollingCorrectionToken],
        baseline: Path
    ) -> Bool {
        path.changedIndices.allSatisfy { index in
            guard baseline.analyses[index].wordIsValid == false else { return true }
            guard let response = tokens[index].correctionResponse,
                  let selectedIndex = response.suggestions.firstIndex(where: {
                      normalize($0.word) == path.words[index]
                  }) else { return false }
            guard selectedIndex == 0 else { return true }
            return response.automaticCorrectionProbability
                >= leadingInvalidCandidateActionProbability
        }
    }

    private static func hasSelectedSpellingSupport(
        path: Path,
        tokens: [RollingCorrectionToken],
        baseline: Path
    ) -> Bool {
        path.changedIndices.allSatisfy { index in
            guard baseline.analyses[index].wordIsValid == false else { return true }
            guard let response = tokens[index].correctionResponse,
                  let suggestion = response.suggestions.first(where: {
                      normalize($0.word) == path.words[index]
                  }) else { return false }
            return suggestion.rankProbability >= strongInvalidCandidateProbability
                || (
                    suggestion.rankProbability
                        >= contextualInvalidCandidateProbability
                        && response.automaticCorrectionProbability
                            >= contextualInvalidActionProbability
                )
        }
    }

    private static func pathPreviousWords(
        _ pathWords: [String],
        fallback: [String]
    ) -> [String] {
        var result = Array(pathWords.suffix(2).reversed())
        if result.count < 2 {
            result.append(contentsOf: fallback.prefix(2 - result.count))
        }
        return result
    }

    private static func transitionScore(_ analysis: WordLanguageAnalysis) -> Double {
        if analysis.precedingTrigramObserved {
            let backoff = analysis.precedingPairObserved
                ? analysis.precedingLogProbability
                : analysis.unigramLogProbability
            return 0.72 * analysis.precedingTrigramLogProbability
                + 0.2 * backoff
                + 0.08 * analysis.unigramLogProbability
        }
        if analysis.precedingPairObserved {
            return 0.86 * analysis.precedingLogProbability
                + 0.14 * analysis.unigramLogProbability
        }
        return analysis.unigramLogProbability - 0.8
    }

    private static func editPenalty(for candidate: Candidate) -> Double {
        guard candidate.isLiteral == false else { return 0 }
        return 0.4 - 0.18 * log(max(candidate.probability, 0.0001))
    }

    private static func hasLaterContextEvidence(for path: Path) -> Bool {
        path.changedIndices.allSatisfy { changedIndex in
            let followingIndex = changedIndex + 1
            let secondFollowingIndex = changedIndex + 2
            let immediateEvidence = followingIndex < path.analyses.count && (
                path.analyses[followingIndex].precedingPairObserved
                    || path.analyses[followingIndex].precedingTrigramObserved
            )
            let delayedEvidence = secondFollowingIndex < path.analyses.count
                && path.analyses[secondFollowingIndex].precedingTrigramObserved
            return immediateEvidence || delayedEvidence
        }
    }

    private static func pathRanksBefore(_ left: Path, _ right: Path) -> Bool {
        if left.score != right.score {
            return left.score > right.score
        }
        if left.changedIndices.count != right.changedIndices.count {
            return left.changedIndices.count < right.changedIndices.count
        }
        return left.words.lexicographicallyPrecedes(right.words)
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    private static func editDistance(_ left: String, _ right: String) -> Int {
        let leftCharacters = Array(left)
        let rightCharacters = Array(right)
        guard leftCharacters.isEmpty == false else { return rightCharacters.count }
        guard rightCharacters.isEmpty == false else { return leftCharacters.count }

        var previousPrevious = Array(0...rightCharacters.count)
        var previous = previousPrevious
        var current = previousPrevious

        for leftIndex in 1...leftCharacters.count {
            current[0] = leftIndex
            for rightIndex in 1...rightCharacters.count {
                let substitution = previous[rightIndex - 1]
                    + (leftCharacters[leftIndex - 1] == rightCharacters[rightIndex - 1] ? 0 : 1)
                current[rightIndex] = min(
                    previous[rightIndex] + 1,
                    current[rightIndex - 1] + 1,
                    substitution
                )
                if leftIndex > 1,
                   rightIndex > 1,
                   leftCharacters[leftIndex - 1] == rightCharacters[rightIndex - 2],
                   leftCharacters[leftIndex - 2] == rightCharacters[rightIndex - 1] {
                    current[rightIndex] = min(
                        current[rightIndex],
                        previousPrevious[rightIndex - 2] + 1
                    )
                }
            }
            previousPrevious = previous
            previous = current
        }
        return previous[rightCharacters.count]
    }
}
