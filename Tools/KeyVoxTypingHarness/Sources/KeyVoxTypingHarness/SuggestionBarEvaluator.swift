import KeyVoxPredictiveKeyboard

/// Replays a word letter by letter with its simulated touches and records, after each
/// letter, whether the intended word is visible in the July three-slot bar and in the
/// engine's top three completions.
struct SuggestionBarEvaluator {
    struct Outcome {
        let letterCount: Int
        /// Letters typed when the intended word first showed in the July bar.
        let lettersTypedWhenShownByJulyBar: Int?
        /// Letters typed when the intended word first showed among the top completions.
        let lettersTypedWhenShownByCompletions: Int?
        /// Mid-word steps (before the last letter) observed.
        let midWordSteps: Int
        /// Mid-word steps whose first July slot does not continue the typed letters.
        let midWordStepsLeadingWithNonContinuation: Int
    }

    let engine: EnglishPredictiveEngine

    func evaluate(
        intendedWord: String,
        typing: SimulatedTyping,
        previousWords: [String],
        usesTouches: Bool
    ) throws -> Outcome {
        let typedLetters = Array(typing.typedWord)
        var shownByJulyBar: Int?
        var shownByCompletions: Int?
        var midWordSteps = 0
        var nonContinuationSteps = 0

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
            let slots = JulySuggestionBar.slots(
                literal: prefix,
                completionSuggestions: completion.suggestions,
                correctionResponse: correction
            )
            if shownByJulyBar == nil, slots.contains(where: { $0.lowercased() == intendedWord }) {
                shownByJulyBar = typedCount
            }
            let topCompletions = completion.suggestions.prefix(CompletionEvaluator.visibleCompletionCount)
            if shownByCompletions == nil,
               topCompletions.contains(where: { $0.word.lowercased() == intendedWord }) {
                shownByCompletions = typedCount
            }
            if typedCount < typedLetters.count {
                midWordSteps += 1
                if let leading = slots.first?.lowercased(), leading.hasPrefix(prefix) == false {
                    nonContinuationSteps += 1
                }
            }
        }

        return Outcome(
            letterCount: typedLetters.count,
            lettersTypedWhenShownByJulyBar: shownByJulyBar,
            lettersTypedWhenShownByCompletions: shownByCompletions,
            midWordSteps: midWordSteps,
            midWordStepsLeadingWithNonContinuation: nonContinuationSteps
        )
    }
}
