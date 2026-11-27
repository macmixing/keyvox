import Foundation

/// How a swipe's candidates rank. A form (`SwipeLetterForm`) with key-path length `L`, CTC
/// log-probability `log p`, and dictionary probability `f` (0 to 255, already log-scaled, its
/// likeliest spelling's) scores
///
///     log p / L^gamma + frequencyWeight * f + lengthBonus * L
///
/// as `Tools/KeyVoxSwipeModel/scoring.py` ranks it. Each of its spellings then takes its own
/// probability in place of the form's, and adds `contextWeight` times how much likelier the
/// words before make it (`ContextLanguageScorer`), so with no lift the likeliest spelling of a
/// form scores exactly the form's score.
struct SwipeCandidateScoring {
    let settings: SwipeModelSettings.Scoring

    func formScore(logProbability: Double, pathLength: Int, frequency: Double) -> Double {
        let length = Double(pathLength)
        return logProbability / pow(max(length, 1), settings.gamma)
            + settings.frequencyWeight * frequency
            + settings.lengthBonus * length
    }

    func spellingScore(
        formScore: Double,
        formFrequency: Double,
        spellingFrequency: Double,
        contextLift: Double
    ) -> Double {
        formScore
            + settings.frequencyWeight * (spellingFrequency - formFrequency)
            + settings.contextWeight * contextLift
    }
}
