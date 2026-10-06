import KeyVoxPredictiveKeyboard

/// Decides what space does to a typed word, using the same engine call and the same
/// gate order as the July `feat/abc-keyboard` keyboard: the grammatical "i" fix,
/// then no change for dictionary words, then the automatic-correction policy.
///
/// The July keyboard's follow-up recoveries (four-letter context, missing-space
/// split, rolling context) are not applied here; this measures the primary path.
struct CorrectionEvaluator {
    let engine: EnglishPredictiveEngine

    func evaluate(
        intendedWord: String,
        typing: SimulatedTyping,
        previousWords: [String],
        usesTouches: Bool
    ) throws -> CorrectionOutcome {
        let response = try engine.predict(
            typedWord: typing.typedWord,
            previousWords: previousWords,
            touches: usesTouches ? typing.touches : [],
            mode: .correction
        )
        let decision = Self.decision(typedWord: typing.typedWord, response: response)
        return CorrectionOutcome(
            intendedWord: intendedWord,
            typedWord: typing.typedWord,
            previousWords: previousWords,
            suggestions: response.suggestions.map(\.word),
            typedWordIsValid: response.typedWordIsValid,
            automaticCorrectionProbability: response.automaticCorrectionProbability,
            correction: decision.replacement,
            reason: decision.reason
        )
    }

    private static func decision(
        typedWord: String,
        response: PredictionResponse
    ) -> (replacement: String?, reason: String) {
        if let replacement = EnglishAutomaticCorrectionPolicy.grammaticalReplacement(
            for: typedWord
        ) {
            return (replacement, AutomaticCorrectionSelectionReason.grammaticalReplacement.rawValue)
        }
        guard response.typedWordIsValid == false else {
            return (nil, AutomaticCorrectionSelectionReason.typedWordValid.rawValue)
        }
        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: typedWord,
            response: response
        )
        guard let suggestion = selection.suggestion,
              suggestion.word.caseInsensitiveCompare(typedWord) != .orderedSame else {
            return (nil, selection.reason.rawValue)
        }
        return (suggestion.word, selection.reason.rawValue)
    }
}
