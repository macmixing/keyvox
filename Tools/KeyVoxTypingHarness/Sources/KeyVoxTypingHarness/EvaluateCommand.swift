import Foundation

/// `evaluate`: types a plan through KeyVox and prints autocorrect, bar, completion,
/// next-word, and speed results.
enum EvaluateCommand {
    static func run(_ options: HarnessCommand.EvaluateOptions) throws {
        let plan = try options.source.resolvePlan()
        let setup = try EngineSetup()
        let typer = SentenceTyper(setup: setup, usesTouches: options.usesTouches)
        let completion = CompletionEvaluator(engine: setup.engine)
        let nextWord = NextWordEvaluator(engine: setup.engine)
        let suggestionBar = SuggestionBarEvaluator(engine: setup.engine)
        var report = EvaluationReport()
        report.engineStartupMilliseconds = setup.startupMilliseconds

        for sentence in plan.sentences {
            report.recordSentence()
            let typedWords = try typer.type(sentence)
            for (index, typedWord) in typedWords.enumerated() {
                let word = sentence.words[index]
                let cleanPreviousWords = Array(sentence.words[..<index].reversed().prefix(3))
                report.record(typedWord.outcome, milliseconds: typedWord.milliseconds)
                report.record(try suggestionBar.evaluate(
                    intendedWord: word,
                    typing: typedWord.typing,
                    previousWords: typedWord.outcome.previousWords,
                    usesTouches: options.usesTouches
                ))
                report.record(try completion.evaluate(
                    intendedWord: word,
                    previousWords: cleanPreviousWords
                ))
                if cleanPreviousWords.isEmpty == false {
                    report.record(try nextWord.evaluate(
                        intendedWord: word,
                        previousWords: cleanPreviousWords
                    ))
                }
            }
        }

        print(ReportPrinter.render(
            report,
            noiseInKeyPitches: plan.noiseInKeyPitches,
            usesTouches: options.usesTouches
        ))
        if let failuresPath = options.failuresPath {
            try ReportPrinter.failureRows(report).write(
                toFile: failuresPath,
                atomically: true,
                encoding: .utf8
            )
            print("Failures written to \(failuresPath)")
        }
    }
}
