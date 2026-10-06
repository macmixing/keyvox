import Foundation
import KeyVoxPredictiveKeyboard

/// `tune`: freezes every planned word's engine candidates once, then searches the
/// noisy-channel parameters on the tuning plans and reports the result on held-out plans.
enum TuneCommand {
    static func run(_ options: HarnessCommand.TuneOptions) throws {
        let setup = try EngineSetup()
        let cache = CachedLanguageAnalysis(engine: setup.engine)
        let language = ContextLanguageScorer(analyze: { try cache.analyze($0, $1) })
        let tuning = try samples(planPaths: options.tuningPlanPaths, setup: setup)
        let holdout = try samples(planPaths: options.holdoutPlanPaths, setup: setup)
        print("Tuning on \(tuning.count) words, holding out \(holdout.count) words")

        let score = { (samples: [TuningSample], parameters: NoisyChannelCorrector.Parameters) in
            try channelScore(samples, parameters: parameters, keys: setup.keys, language: language)
        }
        print("July decider     tuning: \(julyScore(tuning).summary)")
        print("Standard channel tuning: \(try score(tuning, NoisyChannelCorrector.standardParameters).summary)")

        let (best, bestScore) = try ParameterSearch.search(
            from: NoisyChannelCorrector.standardParameters,
            passes: options.passes,
            score: { try score(tuning, $0) },
            onImprovement: { name, value, result in
                print("  \(name) = \(value)  →  \(result.summary)")
            }
        )
        print("Tuned channel    tuning: \(bestScore.summary)")
        if holdout.isEmpty == false {
            print("July decider     holdout: \(julyScore(holdout).summary)")
            print("Standard channel holdout: \(try score(holdout, NoisyChannelCorrector.standardParameters).summary)")
            print("Tuned channel    holdout: \(try score(holdout, best).summary)")
        }
        print("Tuned parameters: \(best)")
    }

    private static func samples(planPaths: [String], setup: EngineSetup) throws -> [TuningSample] {
        var samples: [TuningSample] = []
        let july = setup.correctionEvaluator(decider: .july)
        for path in planPaths {
            let plan = try TypingPlan.load(from: path)
            for sentence in plan.sentences {
                for (index, (word, offsets)) in zip(sentence.words, sentence.taps).enumerated() {
                    let typing = SimulatedTyping(
                        intendedWord: word,
                        offsetsInKeyPitches: offsets,
                        layout: setup.layout
                    )
                    let previousWords = Array(sentence.words[..<index].reversed().prefix(3))
                    let julyOutcome = try july.evaluate(
                        intendedWord: word,
                        typing: typing,
                        previousWords: previousWords,
                        usesTouches: true
                    )
                    samples.append(TuningSample(
                        intendedWord: word,
                        typedWord: typing.typedWord,
                        touches: typing.touches.map(\.location),
                        previousWords: previousWords,
                        candidates: julyOutcome.suggestions,
                        julyFinalWord: julyOutcome.finalWord.lowercased()
                    ))
                }
            }
        }
        return samples
    }

    private static func julyScore(_ samples: [TuningSample]) -> TuningScore {
        var score = TuningScore()
        for sample in samples {
            score.record(intended: sample.intendedWord, typed: sample.typedWord, final: sample.julyFinalWord)
        }
        return score
    }

    private static func channelScore(
        _ samples: [TuningSample],
        parameters: NoisyChannelCorrector.Parameters,
        keys: KeyCenterMap,
        language: ContextLanguageScorer
    ) throws -> TuningScore {
        let corrector = NoisyChannelCorrector(parameters: parameters, keys: keys, language: language)
        var score = TuningScore()
        for sample in samples {
            let final: String
            if let grammatical = EnglishAutomaticCorrectionPolicy.grammaticalReplacement(
                for: sample.typedWord
            ) {
                final = grammatical.lowercased()
            } else {
                final = try corrector.decide(
                    typedWord: sample.typedWord,
                    touches: sample.touches,
                    previousWords: sample.previousWords,
                    candidates: sample.candidates
                ).replacement ?? sample.typedWord
            }
            score.record(intended: sample.intendedWord, typed: sample.typedWord, final: final)
        }
        return score
    }
}
