import KeyVoxPredictiveKeyboard

/// Replays a word letter by letter with its simulated touches and records, after each
/// letter, whether the intended word is visible in the engine's top three completions and
/// in the composed KeyVox bar.
struct SuggestionBarEvaluator {
    struct Outcome {
        let letterCount: Int
        /// Letters typed when the intended word first showed among the top completions.
        let lettersTypedWhenShownByCompletions: Int?
        /// Letters typed when the intended word first showed in the composed bar.
        let lettersTypedWhenShownByComposedBar: Int?
        /// Mid-word steps (before the last letter) observed.
        let midWordSteps: Int
        /// Mid-word steps whose composed primary item does not begin with the intended letters so far.
        let midWordStepsComposedPrimaryNonContinuation: Int
    }

    let engine: EnglishPredictiveEngine
    let ranker: SuggestionCandidateRanker
    let corrector: NoisyChannelCorrector

    func evaluate(
        intendedWord: String,
        typing: SimulatedTyping,
        previousWords: [String],
        usesTouches: Bool
    ) throws -> Outcome {
        let typedLetters = Array(typing.typedWord)
        var shownByCompletions: Int?
        var shownByComposedBar: Int?
        var midWordSteps = 0
        var composedNonContinuationSteps = 0

        for typedCount in 1...max(1, typedLetters.count) where typedLetters.isEmpty == false {
            let prefix = String(typedLetters.prefix(typedCount))
            let touches = usesTouches ? Array(typing.touches.prefix(typedCount)) : []
            let completion = try engine.predict(
                typedWord: prefix,
                previousWords: previousWords,
                touches: touches,
                mode: .completion
            )
            let correction = try engine.predict(
                typedWord: prefix,
                previousWords: previousWords,
                touches: touches,
                mode: .correction
            )
            let composed = try composedBar(
                prefix: prefix,
                touches: touches,
                previousWords: previousWords,
                completion: completion,
                correction: correction
            )
            if shownByComposedBar == nil,
               composed.items.contains(where: { $0.text.lowercased() == intendedWord }) {
                shownByComposedBar = typedCount
            }
            let topCompletions = completion.suggestions.prefix(CompletionEvaluator.visibleCompletionCount)
            if shownByCompletions == nil,
               topCompletions.contains(where: { $0.word.lowercased() == intendedWord }) {
                shownByCompletions = typedCount
            }
            let intendedPrefix = String(intendedWord.filter { $0 != "'" }.prefix(typedCount))
            if typedCount < typedLetters.count {
                midWordSteps += 1
                if let primary = composed.primary?.text.lowercased(), primary.hasPrefix(intendedPrefix) == false {
                    composedNonContinuationSteps += 1
                }
            }
        }

        return Outcome(
            letterCount: typedLetters.count,
            lettersTypedWhenShownByCompletions: shownByCompletions,
            lettersTypedWhenShownByComposedBar: shownByComposedBar,
            midWordSteps: midWordSteps,
            midWordStepsComposedPrimaryNonContinuation: composedNonContinuationSteps
        )
    }

    private func composedBar(
        prefix: String,
        touches: [PredictionTouch],
        previousWords: [String],
        completion: PredictionResponse,
        correction: PredictionResponse
    ) throws -> SuggestionBar {
        let points = touches.map(\.location)
        let candidates = completion.suggestions.map(\.word) + correction.suggestions.map(\.word)
        let ranked = try ranker.rank(
            typedWord: prefix,
            touches: points,
            previousWords: previousWords,
            candidates: candidates
        )
        let decision = try corrector.decide(
            typedWord: prefix,
            touches: points,
            previousWords: previousWords,
            candidates: correction.suggestions.map(\.word)
        )
        return SuggestionBarComposer.compose(
            typedWord: prefix,
            autocorrection: decision.replacement,
            rankedWords: ranked.map(\.word)
        )
    }
}
