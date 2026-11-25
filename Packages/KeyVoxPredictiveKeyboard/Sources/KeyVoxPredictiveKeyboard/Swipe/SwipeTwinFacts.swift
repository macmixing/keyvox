import Foundation

/// What the typing language's own data says about a spelling, for weighing a word against a
/// doubled-letter twin (`SwipeWordDecoder`): how often people write it, from the context model, as
/// a natural log.
struct SwipeTwinFacts: Equatable {
    let logFrequency: Double

    /// The facts `engine`'s language gives `spelling`, a swipe lexicon spelling.
    init(spelling: String, engine: PredictiveEngine) {
        logFrequency = (try? engine.analyze(word: spelling)).map(\.unigramLogProbability) ?? -.infinity
    }

    init(logFrequency: Double) {
        self.logFrequency = logFrequency
    }
}
