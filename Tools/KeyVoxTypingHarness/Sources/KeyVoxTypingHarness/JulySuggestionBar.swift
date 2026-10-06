import KeyVoxPredictiveKeyboard

/// The three suggestion-bar slots exactly as the July `feat/abc-keyboard` keyboard
/// chose them (`KeyboardPredictionCoordinator.makeChoices`), with an empty system
/// lexicon and no KeyVox dictionary match. Kept only as a baseline to measure
/// against; it is not the bar KeyVox will ship.
enum JulySuggestionBar {
    static func slots(
        literal: String,
        completionSuggestions: [PredictiveSuggestion],
        correctionResponse: PredictionResponse
    ) -> [String] {
        var observed: Set<String> = [literal.lowercased()]
        var candidates: [String] = []

        if let grammatical = EnglishAutomaticCorrectionPolicy.grammaticalReplacement(for: literal) {
            candidates.append(grammatical)
        }

        let policySelection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: literal,
            response: correctionResponse
        )
        if correctionResponse.typedWordIsValid == false,
           literal.count >= 2,
           let correction = policySelection.suggestion ?? correctionResponse.suggestions.first,
           observed.insert(correction.word.lowercased()).inserted {
            candidates.append(correction.word)
        }

        for suggestion in completionSuggestions
        where observed.insert(suggestion.word.lowercased()).inserted {
            candidates.append(suggestion.word)
        }

        switch candidates.count {
        case 0:
            return [literal]
        case 1:
            return [candidates[0], literal]
        default:
            return [candidates[0], literal, candidates[1]]
        }
    }
}
