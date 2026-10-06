import Foundation
import KeyVoxPredictiveKeyboard

@main
struct TypingHarness {
    static func main() {
        do {
            let options = try HarnessOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            try run(options)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(_ options: HarnessOptions) throws {
        var shuffleGenerator = SeededRandomGenerator(seed: options.seed ^ 0x5EED)
        let sentences = try CorpusLoader.sentences(from: options.corpusPaths)
            .compactMap(SentenceWords.init(sentence:))
            .shuffled(using: &shuffleGenerator)
            .prefix(options.sentenceLimit)

        let startup = ContinuousClock.now
        let engine = try EnglishPredictiveEngine()
        let layout = KeyboardLayoutModel()
        engine.updateKeyboardGeometry(layout.predictionGeometry, keyboardSize: layout.keyboardSize)
        var report = EvaluationReport()
        report.engineStartupMilliseconds = milliseconds(since: startup)

        let correction = CorrectionEvaluator(engine: engine)
        let completion = CompletionEvaluator(engine: engine)
        let nextWord = NextWordEvaluator(engine: engine)
        var typingGenerator = SeededRandomGenerator(seed: options.seed)

        for sentence in sentences {
            report.recordSentence()
            for (index, word) in sentence.words.enumerated() {
                let previousWords = sentence.previousWords(before: index)
                let typing = SimulatedTyping(
                    intendedWord: word,
                    layout: layout,
                    noiseStandardDeviation: options.noiseStandardDeviation,
                    generator: &typingGenerator
                )
                let started = ContinuousClock.now
                let outcome = try correction.evaluate(
                    intendedWord: word,
                    typing: typing,
                    previousWords: previousWords,
                    usesTouches: options.usesTouches
                )
                report.record(outcome, milliseconds: milliseconds(since: started))
                report.record(try completion.evaluate(intendedWord: word, previousWords: previousWords))
                if previousWords.isEmpty == false {
                    report.record(try nextWord.evaluate(intendedWord: word, previousWords: previousWords))
                }
            }
        }

        print(ReportPrinter.render(report, options: options))
        if let failuresPath = options.failuresPath {
            try ReportPrinter.failureRows(report).write(
                toFile: failuresPath,
                atomically: true,
                encoding: .utf8
            )
            print("Failures written to \(failuresPath)")
        }
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1e15
    }
}
