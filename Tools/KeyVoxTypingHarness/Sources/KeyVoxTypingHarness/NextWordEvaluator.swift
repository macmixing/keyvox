import KeyVoxPredictiveKeyboard

/// Whether the word the user types next is offered before they type any of it.
struct NextWordEvaluator {
    struct Outcome {
        let rank: Int?
    }

    let engine: EnglishPredictiveEngine

    func evaluate(intendedWord: String, previousWords: [String]) throws -> Outcome {
        let response = try engine.predict(
            typedWord: "",
            previousWords: previousWords,
            touches: [],
            mode: .nextWord
        )
        let rank = response.suggestions
            .firstIndex { $0.word.lowercased() == intendedWord }
            .map { $0 + 1 }
        return Outcome(rank: rank)
    }
}
