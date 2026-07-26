import Foundation

public enum AutomaticCorrectionSelectionReason: String, Equatable, Sendable {
    case grammaticalReplacement
    case supplementaryLexicon
    case contextualWordRecovery
    case missingSpaceRecovery
    case rollingContext
    case typedWordValid
    case insufficientInput
    case noSuggestion
    case dominantCandidate
    case actionModel
    case missingLetterRecovery
    case substitutionRecovery
    case transpositionRecovery
    case multiEditRecovery
    case trailingInsertionRecovery
    case ambiguous
}

public struct AutomaticCorrectionSelection: Sendable {
    public let suggestion: PredictiveSuggestion?
    public let reason: AutomaticCorrectionSelectionReason
    public let competingProbability: Double

    public init(
        suggestion: PredictiveSuggestion?,
        reason: AutomaticCorrectionSelectionReason,
        competingProbability: Double
    ) {
        self.suggestion = suggestion
        self.reason = reason
        self.competingProbability = competingProbability
    }
}

public enum EnglishAutomaticCorrectionPolicy {
    private static let dominantCandidateProbability = 0.94
    private static let dominantCandidateMargin = 0.50
    private static let actionModelProbability = 0.995
    private static let missingLetterProbability = 0.04
    private static let missingLetterLeadingProbabilityRatio = 0.08
    private static let missingLetterProbabilityRatio = 8.0
    private static let substitutionProbability = 0.04
    private static let substitutionLeadingProbabilityRatio = 0.10
    private static let substitutionProbabilityRatio = 2.5
    private static let transpositionProbability = 0.005
    private static let transpositionLeadingProbabilityRatio = 0.03
    private static let transpositionProbabilityRatio = 8.0
    private static let trailingInsertionProbability = 0.05
    private static let trailingInsertionActionProbability = 0.80
    private static let trailingInsertionProbabilityRatio = 3.0
    private static let omittedCharactersProbability = 0.08
    private static let omittedCharactersLeadingProbabilityRatio = 0.25
    private static let omittedCharactersProbabilityRatio = 4.0
    private static let multiEditProbability = 0.45
    private static let multiEditLeadingProbabilityRatio = 0.5
    private static let multiEditProbabilityRatio = 5.0

    public static func grammaticalReplacement(for typedWord: String) -> String? {
        typedWord == "i" ? "I" : nil
    }

    public static func select(
        typedWord: String,
        response: PredictionResponse
    ) -> AutomaticCorrectionSelection {
        guard response.typedWordIsValid == false else {
            return AutomaticCorrectionSelection(
                suggestion: nil,
                reason: .typedWordValid,
                competingProbability: 0
            )
        }
        guard typedWord.count >= 2 else {
            return AutomaticCorrectionSelection(
                suggestion: nil,
                reason: .insufficientInput,
                competingProbability: 0
            )
        }
        guard let first = response.suggestions.first else {
            return AutomaticCorrectionSelection(
                suggestion: nil,
                reason: .noSuggestion,
                competingProbability: 0
            )
        }

        let secondProbability = response.suggestions.dropFirst().first?.rankProbability ?? 0
        if first.rankProbability >= dominantCandidateProbability,
           first.rankProbability - secondProbability >= dominantCandidateMargin {
            return AutomaticCorrectionSelection(
                suggestion: first,
                reason: .dominantCandidate,
                competingProbability: secondProbability
            )
        }
        if response.automaticCorrectionProbability >= actionModelProbability {
            return AutomaticCorrectionSelection(
                suggestion: first,
                reason: .actionModel,
                competingProbability: secondProbability
            )
        }

        let missingLetterCandidates = response.suggestions.filter {
            isSingleInternalMissingLetterRepair(
                typedWord: typedWord,
                candidate: $0.word
            )
        }
        if let missingLetterCandidate = missingLetterCandidates.first {
            let competingProbability = missingLetterCandidates.dropFirst()
                .first?.rankProbability ?? 0
            let probabilityRatio = missingLetterCandidate.rankProbability
                / max(competingProbability, .leastNonzeroMagnitude)
            let leadingProbabilityRatio = missingLetterCandidate.rankProbability
                / max(first.rankProbability, .leastNonzeroMagnitude)
            if missingLetterCandidate.rankProbability >= missingLetterProbability,
               leadingProbabilityRatio >= missingLetterLeadingProbabilityRatio,
               probabilityRatio >= missingLetterProbabilityRatio {
                return AutomaticCorrectionSelection(
                    suggestion: missingLetterCandidate,
                    reason: .missingLetterRecovery,
                    competingProbability: competingProbability
                )
            }
        }

        let substitutionCandidates = response.suggestions.filter {
            isSingleSubstitution(
                typedWord: typedWord,
                candidate: $0.word
            )
        }
        if let substitutionCandidate = substitutionCandidates.first {
            let competingProbability = substitutionCandidates.dropFirst()
                .first?.rankProbability ?? 0
            let probabilityRatio = substitutionCandidate.rankProbability
                / max(competingProbability, .leastNonzeroMagnitude)
            let leadingProbabilityRatio = substitutionCandidate.rankProbability
                / max(first.rankProbability, .leastNonzeroMagnitude)
            if substitutionCandidate.rankProbability >= substitutionProbability,
               leadingProbabilityRatio >= substitutionLeadingProbabilityRatio,
               probabilityRatio >= substitutionProbabilityRatio {
                return AutomaticCorrectionSelection(
                    suggestion: substitutionCandidate,
                    reason: .substitutionRecovery,
                    competingProbability: competingProbability
                )
            }
        }

        let transpositionCandidates = response.suggestions.filter {
            isSingleAdjacentTransposition(
                typedWord: typedWord,
                candidate: $0.word
            )
        }
        if let transpositionCandidate = transpositionCandidates.first {
            let competingProbability = transpositionCandidates.dropFirst()
                .first?.rankProbability ?? 0
            let probabilityRatio = transpositionCandidate.rankProbability
                / max(competingProbability, .leastNonzeroMagnitude)
            let leadingProbabilityRatio = transpositionCandidate.rankProbability
                / max(first.rankProbability, .leastNonzeroMagnitude)
            if transpositionCandidate.rankProbability >= transpositionProbability,
               leadingProbabilityRatio >= transpositionLeadingProbabilityRatio,
               probabilityRatio >= transpositionProbabilityRatio {
                return AutomaticCorrectionSelection(
                    suggestion: transpositionCandidate,
                    reason: .transpositionRecovery,
                    competingProbability: competingProbability
                )
            }
        }

        let omittedCharacterCandidates = response.suggestions.filter {
            isOmittedCharactersRepair(
                typedWord: typedWord,
                candidate: $0.word
            )
        }
        if let omittedCharacterCandidate = omittedCharacterCandidates.first {
            let competingProbability = omittedCharacterCandidates.dropFirst()
                .first?.rankProbability ?? 0
            let probabilityRatio = omittedCharacterCandidate.rankProbability
                / max(competingProbability, .leastNonzeroMagnitude)
            let leadingProbabilityRatio = omittedCharacterCandidate.rankProbability
                / max(first.rankProbability, .leastNonzeroMagnitude)
            if omittedCharacterCandidate.rankProbability >= omittedCharactersProbability,
               leadingProbabilityRatio >= omittedCharactersLeadingProbabilityRatio,
               probabilityRatio >= omittedCharactersProbabilityRatio {
                return AutomaticCorrectionSelection(
                    suggestion: omittedCharacterCandidate,
                    reason: .missingLetterRecovery,
                    competingProbability: competingProbability
                )
            }
        }

        let multiEditCandidates = response.suggestions.filter {
            editDistance(typedWord, $0.word) == 2
        }
        if let multiEditCandidate = multiEditCandidates.first {
            let competingProbability = multiEditCandidates.dropFirst()
                .first?.rankProbability ?? 0
            let probabilityRatio = multiEditCandidate.rankProbability
                / max(competingProbability, .leastNonzeroMagnitude)
            let leadingProbabilityRatio = multiEditCandidate.rankProbability
                / max(first.rankProbability, .leastNonzeroMagnitude)
            if multiEditCandidate.rankProbability >= multiEditProbability,
               leadingProbabilityRatio >= multiEditLeadingProbabilityRatio,
               probabilityRatio >= multiEditProbabilityRatio {
                return AutomaticCorrectionSelection(
                    suggestion: multiEditCandidate,
                    reason: .multiEditRecovery,
                    competingProbability: competingProbability
                )
            }
        }

        let normalizedTypedWord = typedWord.lowercased()
        let trailingInsertions = response.suggestions.filter { suggestion in
            let candidate = suggestion.word.lowercased()
            return candidate.count == normalizedTypedWord.count + 1
                && candidate.hasPrefix(normalizedTypedWord)
        }
        if let trailingInsertion = trailingInsertions.first {
            let competingInsertionProbability = trailingInsertions.dropFirst()
                .first?.rankProbability ?? 0
            let probabilityRatio = trailingInsertion.rankProbability
                / max(competingInsertionProbability, .leastNonzeroMagnitude)
            if response.automaticCorrectionProbability >= trailingInsertionActionProbability,
               trailingInsertion.rankProbability >= trailingInsertionProbability,
               probabilityRatio >= trailingInsertionProbabilityRatio {
                return AutomaticCorrectionSelection(
                    suggestion: trailingInsertion,
                    reason: .trailingInsertionRecovery,
                    competingProbability: competingInsertionProbability
                )
            }
        }

        return AutomaticCorrectionSelection(
            suggestion: nil,
            reason: .ambiguous,
            competingProbability: secondProbability
        )
    }

    private static func isSingleInternalMissingLetterRepair(
        typedWord: String,
        candidate: String
    ) -> Bool {
        let typedCharacters = Array(typedWord.lowercased())
        let candidateCharacters = Array(candidate.lowercased())
        guard candidateCharacters.count == typedCharacters.count + 1 else {
            return false
        }

        var typedIndex = 0
        var insertionIndex: Int?
        for (candidateIndex, candidateCharacter) in candidateCharacters.enumerated() {
            if typedIndex < typedCharacters.count,
               candidateCharacter == typedCharacters[typedIndex] {
                typedIndex += 1
            } else if insertionIndex == nil {
                insertionIndex = candidateIndex
            } else {
                return false
            }
        }
        guard typedIndex == typedCharacters.count,
              let insertionIndex else {
            return false
        }
        return insertionIndex > 0 && insertionIndex < candidateCharacters.count - 1
    }

    private static func isSingleAdjacentTransposition(
        typedWord: String,
        candidate: String
    ) -> Bool {
        let typedCharacters = Array(typedWord.lowercased())
        let candidateCharacters = Array(candidate.lowercased())
        guard typedCharacters.count == candidateCharacters.count else {
            return false
        }

        let differences = typedCharacters.indices.filter {
            typedCharacters[$0] != candidateCharacters[$0]
        }
        guard differences.count == 2,
              differences[1] == differences[0] + 1 else {
            return false
        }
        return typedCharacters[differences[0]] == candidateCharacters[differences[1]]
            && typedCharacters[differences[1]] == candidateCharacters[differences[0]]
    }

    private static func isSingleSubstitution(
        typedWord: String,
        candidate: String
    ) -> Bool {
        let typedCharacters = Array(typedWord.lowercased())
        let candidateCharacters = Array(candidate.lowercased())
        guard typedCharacters.count >= 4,
              typedCharacters.count == candidateCharacters.count else {
            return false
        }
        return zip(typedCharacters, candidateCharacters).reduce(into: 0) { count, pair in
            if pair.0 != pair.1 {
                count += 1
            }
        } == 1
    }

    private static func isOmittedCharactersRepair(
        typedWord: String,
        candidate: String
    ) -> Bool {
        let typedCharacters = Array(typedWord.lowercased())
        let candidateCharacters = Array(candidate.lowercased())
        guard candidateCharacters.count == typedCharacters.count + 2,
              candidateCharacters.contains("'") else {
            return false
        }
        var typedIndex = 0
        for character in candidateCharacters where typedIndex < typedCharacters.count {
            if character == typedCharacters[typedIndex] {
                typedIndex += 1
            }
        }
        return typedIndex == typedCharacters.count
    }

    private static func editDistance(_ left: String, _ right: String) -> Int {
        let leftCharacters = Array(left.lowercased())
        let rightCharacters = Array(right.lowercased())
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
