import Foundation

/// What the typing language's own data says about a spelling, for weighing a word against a
/// doubled-letter twin (`SwipeWordDecoder`): whether the dictionary spells it only with capitals, as
/// a name; whether typing takes it as a word at all; and how often people write it, from the context
/// model, as a natural log.
struct SwipeTwinFacts: Equatable {
    let isNameOnly: Bool
    let isValid: Bool
    let logFrequency: Double

    /// The facts `engine`'s language gives `spelling`, a swipe lexicon spelling.
    init(spelling: String, engine: PredictiveEngine) {
        let analysis = try? engine.analyze(word: spelling)
        isNameOnly = engine.capitalizedSpellings.spelling(of: spelling) != nil
        isValid = analysis?.wordIsValid ?? false
        logFrequency = analysis.map(\.unigramLogProbability) ?? -.infinity
    }

    init(isNameOnly: Bool, isValid: Bool, logFrequency: Double) {
        self.isNameOnly = isNameOnly
        self.isValid = isValid
        self.logFrequency = logFrequency
    }
}
