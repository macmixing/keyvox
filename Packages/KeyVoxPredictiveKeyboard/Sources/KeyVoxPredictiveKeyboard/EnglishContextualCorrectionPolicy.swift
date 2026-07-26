import Foundation

public struct MissingSpaceCorrectionSelection: Equatable, Sendable {
    public let replacement: String
    public let languageScore: Double

    public init(replacement: String, languageScore: Double) {
        self.replacement = replacement
        self.languageScore = languageScore
    }
}

public enum EnglishContextualCorrectionPolicy {
    private struct SplitCandidate {
        let replacement: String
        let languageScore: Double
        let hasObservedInternalPair: Bool
        let hasSingleCharacterWord: Bool
    }

    private static let minimumJoinedWordLength = 4
    private static let ambiguousSplitScoreMargin = 2.0
    private static let dominantSpellingRepairProbability = 0.5
    private static let minimumSplitLanguageScore = -25.0
    private static let contextualWordScoreMargin = 2.0

    public static func fourLetterWordCorrection(
        typedWord: String,
        prefixCompletionSuggestions: [PredictiveSuggestion],
        previousWords: [String],
        analyze: (String, [String]) throws -> WordLanguageAnalysis
    ) throws -> PredictiveSuggestion? {
        let normalizedWord = normalize(typedWord)
        guard normalizedWord.count == 4,
              previousWords.isEmpty == false else {
            return nil
        }
        let originalAnalysis = try analyze(normalizedWord, previousWords)
        let contextualCandidates = try prefixCompletionSuggestions.compactMap {
            suggestion -> (PredictiveSuggestion, WordLanguageAnalysis)? in
            let candidate = normalize(suggestion.word)
            guard candidate.count == normalizedWord.count,
                  (1...2).contains(editDistance(normalizedWord, candidate)) else {
                return nil
            }
            let analysis = try analyze(candidate, previousWords)
            guard analysis.precedingPairObserved else { return nil }
            return (suggestion, analysis)
        }.sorted { left, right in
            if left.1.precedingTrigramObserved != right.1.precedingTrigramObserved {
                return left.1.precedingTrigramObserved
            }
            let leftScore = contextualScore(left.1)
            let rightScore = contextualScore(right.1)
            if leftScore != rightScore {
                return leftScore > rightScore
            }
            return left.0.rankProbability > right.0.rankProbability
        }
        guard let best = contextualCandidates.first else { return nil }
        let comparableOriginalContext = best.1.precedingTrigramObserved
            ? originalAnalysis.precedingTrigramObserved
            : originalAnalysis.precedingPairObserved
        if comparableOriginalContext,
           contextualScore(best.1) - contextualScore(originalAnalysis)
                < contextualWordScoreMargin {
            return nil
        }
        return best.0
    }

    private static func contextualScore(_ analysis: WordLanguageAnalysis) -> Double {
        analysis.precedingTrigramObserved
            ? analysis.precedingTrigramLogProbability
            : analysis.precedingLogProbability
    }

    public static func missingSpaceCorrection(
        typedWord: String,
        correctionResponse: PredictionResponse,
        previousWord: String?,
        isSupplementaryWord: (String) -> Bool,
        correctionResponseForWord: ((String, String?) throws -> PredictionResponse)? = nil,
        analyze: (String, String?) throws -> WordLanguageAnalysis
    ) throws -> MissingSpaceCorrectionSelection? {
        let normalizedWord = normalize(typedWord)
        guard normalizedWord.count >= minimumJoinedWordLength else { return nil }

        let wholeAnalysis = try analyze(normalizedWord, previousWord)
        guard wholeAnalysis.wordIsValid == false,
              isSupplementaryWord(normalizedWord) == false else {
            return nil
        }

        var candidates: [SplitCandidate] = []
        for boundaryOffset in 1..<normalizedWord.count {
            let boundary = normalizedWord.index(
                normalizedWord.startIndex,
                offsetBy: boundaryOffset
            )
            let left = String(normalizedWord[..<boundary])
            let right = String(normalizedWord[boundary...])
            let leftAnalysis = try analyze(left, previousWord)
            let rightAnalysis = try analyze(right, left)
            let leftIsKnown = leftAnalysis.wordIsValid || isSupplementaryWord(left)
            let rightIsKnown = rightAnalysis.wordIsValid || isSupplementaryWord(right)
            if leftIsKnown, rightIsKnown {
                appendCandidate(
                    left: left,
                    right: right,
                    leftAnalysis: leftAnalysis,
                    rightAnalysis: rightAnalysis,
                    previousWord: previousWord,
                    into: &candidates
                )
                continue
            }
            guard let correctionResponseForWord else { continue }

            if leftIsKnown,
               let repairedRight = try spellingRepair(
                    for: right,
                    response: correctionResponseForWord(right, left)
               ) {
                let repairedRightAnalysis = try analyze(repairedRight, left)
                guard repairedRightAnalysis.wordIsValid
                        || isSupplementaryWord(repairedRight) else {
                    continue
                }
                appendCandidate(
                    left: left,
                    right: repairedRight,
                    leftAnalysis: leftAnalysis,
                    rightAnalysis: repairedRightAnalysis,
                    previousWord: previousWord,
                    into: &candidates
                )
            } else if rightIsKnown,
                      let repairedLeft = try spellingRepair(
                        for: left,
                        response: correctionResponseForWord(left, previousWord)
                      ) {
                let repairedLeftAnalysis = try analyze(repairedLeft, previousWord)
                let contextualRightAnalysis = try analyze(right, repairedLeft)
                guard repairedLeftAnalysis.wordIsValid
                        || isSupplementaryWord(repairedLeft) else {
                    continue
                }
                appendCandidate(
                    left: repairedLeft,
                    right: right,
                    leftAnalysis: repairedLeftAnalysis,
                    rightAnalysis: contextualRightAnalysis,
                    previousWord: previousWord,
                    into: &candidates
                )
            }
        }

        let ranked = candidates.sorted { left, right in
            if left.hasObservedInternalPair != right.hasObservedInternalPair {
                return left.hasObservedInternalPair
            }
            if left.languageScore != right.languageScore {
                return left.languageScore > right.languageScore
            }
            return left.replacement < right.replacement
        }
        guard let best = ranked.first else { return nil }
        guard best.languageScore >= minimumSplitLanguageScore else { return nil }
        let ordinaryCorrection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: typedWord,
            response: correctionResponse
        )
        if let spellingRepair = ordinaryCorrection.suggestion,
           isApostropheRestoration(
                typedWord: normalizedWord,
                candidate: spellingRepair.word
           ) {
            return nil
        }
        if let spellingRepair = ordinaryCorrection.suggestion,
           spellingRepair.rankProbability >= dominantSpellingRepairProbability,
           best.hasObservedInternalPair == false {
            return nil
        }
        guard best.hasObservedInternalPair || ordinaryCorrection.suggestion == nil else {
            return nil
        }
        if ranked.count > 1 {
            let second = ranked[1]
            guard best.hasObservedInternalPair && (
                second.hasObservedInternalPair == false
                    || best.languageScore - second.languageScore >= ambiguousSplitScoreMargin
            ) else {
                return nil
            }
        }
        return MissingSpaceCorrectionSelection(
            replacement: best.replacement,
            languageScore: best.languageScore
        )
    }

    private static func transitionScore(
        _ analysis: WordLanguageAnalysis,
        hasPreviousWord: Bool
    ) -> Double {
        if hasPreviousWord, analysis.precedingPairObserved {
            return analysis.precedingLogProbability
        }
        return analysis.unigramLogProbability
    }

    private static func appendCandidate(
        left: String,
        right: String,
        leftAnalysis: WordLanguageAnalysis,
        rightAnalysis: WordLanguageAnalysis,
        previousWord: String?,
        into candidates: inout [SplitCandidate]
    ) {
        let hasSingleCharacterWord = left.count == 1 || right.count == 1
        guard hasSingleCharacterWord == false || rightAnalysis.precedingPairObserved else {
            return
        }
        candidates.append(
            SplitCandidate(
                replacement: left + " " + right,
                languageScore: transitionScore(
                    leftAnalysis,
                    hasPreviousWord: previousWord != nil
                ) + transitionScore(rightAnalysis, hasPreviousWord: true),
                hasObservedInternalPair: rightAnalysis.precedingPairObserved,
                hasSingleCharacterWord: hasSingleCharacterWord
            )
        )
    }

    private static func spellingRepair(
        for word: String,
        response: PredictionResponse
    ) throws -> String? {
        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: word,
            response: response
        )
        if let suggestion = selection.suggestion,
           editDistance(word, suggestion.word) == 1 {
            return suggestion.word
        }
        guard let first = response.suggestions.first,
              editDistance(word, first.word) == 1 else {
            return nil
        }
        let secondProbability = response.suggestions.dropFirst()
            .first?.rankProbability ?? 0
        guard first.rankProbability >= 0.5,
              first.rankProbability - secondProbability >= 0.25 else {
            return nil
        }
        return first.word
    }

    private static func isApostropheRestoration(
        typedWord: String,
        candidate: String
    ) -> Bool {
        let normalizedCandidate = normalize(candidate)
        guard normalizedCandidate.contains("'") || normalizedCandidate.contains("’") else {
            return false
        }
        return normalizedCandidate.filter { $0 != "'" && $0 != "’" } == typedWord
    }

    private static func editDistance(_ left: String, _ right: String) -> Int {
        let leftCharacters = Array(normalize(left))
        let rightCharacters = Array(normalize(right))
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

    private static func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "’", with: "'")
    }

}
