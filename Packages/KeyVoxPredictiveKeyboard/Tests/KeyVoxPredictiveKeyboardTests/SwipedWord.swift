@testable import KeyVoxPredictiveKeyboard

/// The best word a typing language's keyboard gives a swipe through the centers of some letters'
/// keys on its layout (`SwipePath`).
enum SwipedWord {
    static func best(swiping letters: String, in language: TypingLanguage) throws -> String? {
        let computer = PredictionComputer(engine: try PredictiveEngine(language: language))
        return try computer.swipeWords(
            for: SwipePath.through(letters, on: language.letterLayout),
            previousWords: [],
            wordCase: .asSpelled,
            limit: 1
        ).first
    }
}
