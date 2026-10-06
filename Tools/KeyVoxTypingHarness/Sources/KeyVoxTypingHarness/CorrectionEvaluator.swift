import KeyVoxPredictiveKeyboard

/// Decides what space does to a typed word with one of two deciders:
///
/// - `july`: the July `feat/abc-keyboard` gate order (the grammatical "i" fix, then no
///   change for dictionary words, then the automatic-correction policy). Its follow-up
///   recoveries (four-letter context, missing-space split, rolling context) are not
///   applied; this measures its primary path.
/// - `channel`: the noisy-channel corrector, which weighs touch positions against
///   context likelihood over the same engine candidates.
struct CorrectionEvaluator {
    enum Decider {
        case july
        case channel(NoisyChannelCorrector.Parameters)
    }

    let engine: EnglishPredictiveEngine
    let decider: Decider
    let keys: KeyCenterMap
    let language: ContextLanguageScorer

    func evaluate(
        intendedWord: String,
        typing: SimulatedTyping,
        previousWords: [String],
        usesTouches: Bool
    ) throws -> CorrectionOutcome {
        let touches = usesTouches ? typing.touches : []
        let response = try engine.predict(
            typedWord: typing.typedWord,
            previousWords: previousWords,
            touches: touches,
            mode: .correction
        )
        switch decider {
        case .july:
            let decision = Self.julyDecision(typedWord: typing.typedWord, response: response)
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
        case .channel(let parameters):
            if let grammatical = EnglishAutomaticCorrectionPolicy.grammaticalReplacement(
                for: typing.typedWord
            ) {
                return CorrectionOutcome(
                    intendedWord: intendedWord,
                    typedWord: typing.typedWord,
                    previousWords: previousWords,
                    suggestions: response.suggestions.map(\.word),
                    typedWordIsValid: response.typedWordIsValid,
                    automaticCorrectionProbability: 0,
                    correction: grammatical,
                    reason: "grammatical"
                )
            }
            let corrector = NoisyChannelCorrector(parameters: parameters, keys: keys, language: language)
            let decision = try corrector.decide(
                typedWord: typing.typedWord,
                touches: touches.map(\.location),
                previousWords: previousWords,
                candidates: response.suggestions.map(\.word)
            )
            return CorrectionOutcome(
                intendedWord: intendedWord,
                typedWord: typing.typedWord,
                previousWords: previousWords,
                suggestions: decision.rankedAlternatives.map(\.word),
                typedWordIsValid: decision.typed.language.isDictionaryWord,
                automaticCorrectionProbability: decision.rankedAlternatives.first
                    .map { $0.score - decision.typed.score } ?? 0,
                correction: decision.replacement,
                reason: decision.replacement == nil ? "kept" : "channel"
            )
        }
    }

    private static func julyDecision(
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
