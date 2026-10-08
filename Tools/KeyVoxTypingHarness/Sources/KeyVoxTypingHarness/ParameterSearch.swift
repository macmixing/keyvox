import KeyVoxPredictiveKeyboard

/// Coordinate descent over the noisy-channel corrector's parameters: each pass tries
/// every listed value of one parameter at a time and keeps any improvement.
enum ParameterSearch {
    struct Dimension {
        let name: String
        let keyPath: WritableKeyPath<NoisyChannelCorrector.Parameters, Double>
        let values: [Double]
    }

    static var dimensions: [Dimension] { [
        Dimension(name: "touchStandardDeviation", keyPath: \.touch.touchStandardDeviation,
                  values: [0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.6, 0.7]),
        Dimension(name: "languageWeight", keyPath: \.languageWeight,
                  values: [0.3, 0.4, 0.5, 0.6, 0.8, 1.0, 1.2, 1.5, 2.0]),
        Dimension(name: "unknownWordPenalty", keyPath: \.unknownWordPenalty,
                  values: [0, 1, 2, 3, 4, 6, 8, 12]),
        Dimension(name: "correctionMargin", keyPath: \.correctionMargin,
                  values: [-2, -1, 0, 0.5, 1, 1.5, 2, 3, 4]),
        Dimension(name: "dictionaryWordCorrectionMargin", keyPath: \.dictionaryWordCorrectionMargin,
                  values: [2, 3, 4, 5, 6, 8, 10, 14, 1_000]),
        Dimension(name: "everydayWordCorrectionMargin", keyPath: \.everydayWordCorrectionMargin,
                  values: [0, 0.5, 1, 2, 3, 4, 6]),
        Dimension(name: "apostropheRestorationMargin", keyPath: \.apostropheRestorationMargin,
                  values: [-2, -1, -0.5, 0, 0.5, 1, 1.5, 2, 3, 5]),
        Dimension(name: "extraTouchCost", keyPath: \.touch.extraTouchCost,
                  values: [2, 3, 4, 5, 6, 8]),
        Dimension(name: "skippedLetterCost", keyPath: \.touch.skippedLetterCost,
                  values: [2, 3, 4, 5, 6, 8]),
        Dimension(name: "skippedRepeatedLetterCost", keyPath: \.touch.skippedRepeatedLetterCost,
                  values: [0.5, 1, 1.5, 2, 3, 4]),
        Dimension(name: "swappedLettersCost", keyPath: \.touch.swappedLettersCost,
                  values: [1, 2, 3, 4, 6]),
        Dimension(name: "revisionMargin", keyPath: \.revisionMargin,
                  values: [0, 1, 2, 3, 4, 5, 6, 8, 12]),
        Dimension(name: "missingSpaceMargin", keyPath: \.missingSpaceMargin,
                  values: [0, 2, 4, 5, 6, 7, 8]),
        Dimension(name: "missingSpaceCorrectionMargin", keyPath: \.missingSpaceCorrectionMargin,
                  values: [-10, -6, -5, -4, -3, -2, 0]),
        Dimension(name: "correctedMissingSpaceCorrectionMargin", keyPath: \.correctedMissingSpaceCorrectionMargin,
                  values: [0, 2, 3, 4, 5, 6, 8]),
        Dimension(name: "correctedMissingSpaceMarginPerLetter", keyPath: \.correctedMissingSpaceMarginPerLetter,
                  values: [0, 0.5, 0.75, 1, 1.25, 1.5]),
    ] }

    static func search(
        from start: NoisyChannelCorrector.Parameters,
        passes: Int,
        score: (NoisyChannelCorrector.Parameters) throws -> TuningScore,
        onImprovement: (String, Double, TuningScore) -> Void
    ) throws -> (NoisyChannelCorrector.Parameters, TuningScore) {
        var best = start
        var bestScore = try score(start)
        for _ in 0..<passes {
            var improvedThisPass = false
            for dimension in dimensions {
                for value in dimension.values where value != best[keyPath: dimension.keyPath] {
                    var candidate = best
                    candidate[keyPath: dimension.keyPath] = value
                    let candidateScore = try score(candidate)
                    if candidateScore.objective > bestScore.objective + 1e-9 {
                        best = candidate
                        bestScore = candidateScore
                        improvedThisPass = true
                        onImprovement(dimension.name, value, candidateScore)
                    }
                }
            }
            if improvedThisPass == false { break }
        }
        return (best, bestScore)
    }
}
