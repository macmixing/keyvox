import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// Decodes swipe.futo.org swipes through the keyboard's swipe path and reports how often the
/// recorded word ranks first, in the top three, and in the top ten, for each context weight
/// asked for, and the swipe decode time; with `--calibrate-personal`, also the dictionary
/// probability of the words seen about as often as typing takes the user's words to be.
enum SwipeAccuracyCommand {
    /// The log-probability typing gives the user's words (`ContextLanguageScorer`): about once
    /// in ten thousand words.
    private static let personalWordLogProbability = log(1e-4)
    /// How close to it, as a natural log, a dictionary word's frequency must be to count.
    private static let calibrationBand = 0.1

    static func run(_ options: HarnessCommand.SwipeAccuracyOptions) throws {
        let futo = try FutoSwipes(path: options.swipesPath, layoutPath: options.layoutPath, limit: options.limit)
        let language = try TypingLanguage.bundled(identifier: options.languageIdentifier, letterLayout: options.letterLayout)
        let settings = try SwipeModelSettings.bundled(for: language)
        let formLetters = settings.formLetters
        let weights = options.contextWeights.isEmpty ? [settings.scoring.contextWeight] : options.contextWeights
        let workers = max(1, ProcessInfo.processInfo.activeProcessorCount - 4)
        let computers = try (0..<workers).map { _ in try PredictionComputer(engine: PredictiveEngine(language: language)) }
        let ranks = UnsafeMutableBufferPointer<[Int]>.allocate(capacity: futo.swipes.count)
        let seconds = UnsafeMutableBufferPointer<Double>.allocate(capacity: futo.swipes.count)
        ranks.initialize(repeating: [])
        seconds.initialize(repeating: 0)
        defer {
            ranks.deinitialize()
            ranks.deallocate()
            seconds.deallocate()
        }
        let started = ContinuousClock.now
        DispatchQueue.concurrentPerform(iterations: workers) { worker in
            let computer = computers[worker]
            var canvas = CGSize.zero
            for index in stride(from: worker, to: futo.swipes.count, by: workers) {
                let swipe = futo.swipes[index]
                if swipe.canvas != canvas {
                    canvas = swipe.canvas
                    computer.updateKeyboardGeometry(futo.keyGeometry(for: canvas), keyboardSize: canvas)
                }
                let target = SwipeLetterForm.form(of: swipe.word, letters: formLetters)
                let decodeStart = ContinuousClock.now
                let candidates = (try? computer.swipeCandidates(
                    for: swipe.samples,
                    previousWords: options.usesContext ? swipe.previousWords.map { $0.lowercased() } : []
                )) ?? []
                seconds[index] = EngineSetup.milliseconds(since: decodeStart) / 1_000
                ranks[index] = weights.map { weight in
                    let rescored = candidates.map {
                        ($0, $0.score + (weight - settings.scoring.contextWeight) * $0.contextLift)
                    }.sorted { $0.1 > $1.1 }
                    var forms: [String] = []
                    for (candidate, _) in rescored {
                        let form = SwipeLetterForm.form(of: candidate.spelling, letters: formLetters)
                        if forms.contains(form) == false { forms.append(form) }
                        if form == target { return forms.count - 1 }
                    }
                    return Int.max
                }
            }
        }
        let count = Double(futo.swipes.count)
        print("swipes: \(futo.swipes.count)  context: \(options.usesContext ? "on" : "off")  wall: \(Int(EngineSetup.milliseconds(since: started) / 1_000)) s")
        for (column, weight) in weights.enumerated() {
            let columnRanks = ranks.map { $0[column] }
            let top = { (k: Int) in Double(columnRanks.filter { $0 < k }.count) / count * 100 }
            print(String(format: "  context weight %.3f: top1 %.2f%%  top3 %.2f%%  top10 %.2f%%", weight, top(1), top(3), top(10)))
        }
        let sorted = seconds.sorted()
        print(String(format: "  decode ms p50 %.2f  p95 %.2f  max %.2f",
                     sorted[sorted.count / 2] * 1_000, sorted[sorted.count * 95 / 100] * 1_000, sorted[sorted.count - 1] * 1_000))
        if options.calibratesPersonalWords {
            try printPersonalFrequency(engine: PredictiveEngine(language: language))
        }
    }

    /// The median dictionary probability of the dictionary's words the context counts see about
    /// as often as typing takes the user's words to be.
    private static func printPersonalFrequency(engine: PredictiveEngine) throws {
        var frequencies: [Int] = []
        for word in try engine.dictionaryWords() where word.isOfferable {
            let unigram = try engine.analyze(word: word.spelling, previousWords: []).unigramLogProbability
            if abs(unigram - personalWordLogProbability) <= calibrationBand {
                frequencies.append(word.probability)
            }
        }
        frequencies.sort()
        guard frequencies.isEmpty == false else { return print("  no dictionary word is that frequent") }
        print("  personal word frequency: median \(frequencies[frequencies.count / 2]) of \(frequencies.count) words (p25 \(frequencies[frequencies.count / 4]), p75 \(frequencies[frequencies.count * 3 / 4]))")
    }

}
