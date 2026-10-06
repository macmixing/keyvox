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
        let holdouts = try options.holdoutPlanPaths.map { path in
            (name: URL(fileURLWithPath: path).lastPathComponent, samples: try samples(planPaths: [path], setup: setup))
        }
        print("Tuning on \(tuning.count) words, holding out \(holdouts.reduce(0) { $0 + $1.samples.count }) words")

        let score = { (samples: [TuningSample], parameters: NoisyChannelCorrector.Parameters) in
            try channelScore(samples, parameters: parameters, keys: setup.keys, language: language)
        }
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
        for holdout in holdouts {
            print("Holdout \(holdout.name):")
            print("  Standard channel: \(try score(holdout.samples, NoisyChannelCorrector.standardParameters).summary)")
            print("  Tuned channel:    \(try score(holdout.samples, best).summary)")
        }
        print("Tuned parameters: \(best)")
    }

    private static func samples(planPaths: [String], setup: EngineSetup) throws -> [TuningSample] {
        var samples: [TuningSample] = []
        for path in planPaths {
            let plan = try TypingPlan.load(from: path)
            for sentence in plan.sentences {
                for (index, (word, offsets)) in zip(sentence.words, sentence.taps).enumerated() {
                    let typing = SimulatedTyping(
                        tappedWord: word,
                        offsetsInKeyPitches: offsets,
                        layout: setup.layout
                    )
                    let previousWords = Array(sentence.truthWords[..<index].reversed().prefix(3))
                    let intendedWord = sentence.truthWords[index]
                    let response = try setup.engine.predict(
                        typedWord: typing.typedWord,
                        previousWords: previousWords,
                        touches: typing.touches,
                        mode: .correction
                    )
                    samples.append(TuningSample(
                        intendedWord: intendedWord,
                        typedWord: typing.typedWord,
                        touches: typing.touches.map(\.location),
                        previousWords: previousWords,
                        candidates: response.suggestions.map(\.word)
                    ))
                }
            }
        }
        return samples
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
            let final = try corrector.decide(
                typedWord: sample.typedWord,
                touches: sample.touches,
                previousWords: sample.previousWords,
                candidates: sample.candidates
            ).replacement ?? sample.typedWord
            score.record(intended: sample.intendedWord, typed: sample.typedWord, final: final)
        }
        return score
    }
}
