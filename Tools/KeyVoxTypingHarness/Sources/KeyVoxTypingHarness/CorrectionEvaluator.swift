import KeyVoxPredictiveKeyboard

/// Decides what space does to a typed word with the noisy-channel corrector, which weighs
/// touch positions against context likelihood over the engine's candidates.
struct CorrectionEvaluator {
    let engine: EnglishPredictiveEngine
    let parameters: NoisyChannelCorrector.Parameters
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
        let corrector = NoisyChannelCorrector(parameters: parameters, keys: keys, language: language)
        let decision = try corrector.decide(
            typedWord: typing.typedWord,
            touches: touches.map(\.location),
            previousWords: previousWords,
            candidates: response.suggestions.map(\.word)
        )
        let written = WordCasing.apply(of: typing.typedWord, to: decision.replacement ?? typing.typedWord)
        return CorrectionOutcome(
            intendedWord: intendedWord,
            typedWord: typing.typedWord,
            previousWords: previousWords,
            suggestions: decision.rankedAlternatives.map(\.word),
            typedWordIsValid: decision.typed.language.isDictionaryWord,
            automaticCorrectionProbability: decision.rankedAlternatives.first
                .map { $0.score - decision.typed.score } ?? 0,
            correction: written == typing.typedWord ? nil : written,
            reason: decision.replacement == nil ? "kept" : "channel"
        )
    }
}
