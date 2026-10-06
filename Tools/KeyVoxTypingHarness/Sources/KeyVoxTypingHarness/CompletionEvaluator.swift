import KeyVoxPredictiveKeyboard

/// How early the intended word appears among the top three completions while its
/// letters are typed cleanly, one prefix at a time.
struct CompletionEvaluator {
    struct Outcome {
        /// Letters typed before the word first appeared in the top three, if it did.
        let lettersTypedWhenOffered: Int?
        /// Letters needed to type the word in full (apostrophes excluded).
        let letterCount: Int
    }

    static let visibleCompletionCount = 3

    let engine: EnglishPredictiveEngine

    func evaluate(intendedWord: String, previousWords: [String]) throws -> Outcome {
        let letters = Array(intendedWord.filter { $0 != "'" })
        guard letters.count >= 2 else {
            return Outcome(lettersTypedWhenOffered: nil, letterCount: letters.count)
        }
        for typedCount in 1..<letters.count {
            let response = try engine.predict(
                typedWord: String(letters.prefix(typedCount)),
                previousWords: previousWords,
                touches: [],
                mode: .completion
            )
            let offered = response.suggestions
                .prefix(Self.visibleCompletionCount)
                .contains { $0.word.lowercased() == intendedWord }
            if offered {
                return Outcome(lettersTypedWhenOffered: typedCount, letterCount: letters.count)
            }
        }
        return Outcome(lettersTypedWhenOffered: nil, letterCount: letters.count)
    }
}
