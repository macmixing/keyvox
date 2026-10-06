import Foundation

/// `compare`: types the plan through KeyVox and scores it word for word against what
/// the Apple keyboard produced from the same planned taps.
enum CompareCommand {
    static func run(_ options: HarnessCommand.CompareOptions) throws {
        let plan = try TypingPlan.load(from: options.planPath)
        let apple = try AppleBaselineResults.load(from: options.appleResultsPath)
        guard apple.sentences.count == plan.sentences.count else {
            throw HarnessError.planMismatch(
                "\(apple.sentences.count) Apple sentences for \(plan.sentences.count) planned"
            )
        }
        let typer = SentenceTyper(setup: try EngineSetup(), decider: options.decider, usesTouches: true)

        var total = 0
        var appleCorrect = 0
        var keyVoxCorrect = 0
        var bothCorrect = 0
        var rows = ["intended\tapple\tkeyvox\tkeyvox_typed\tprevious"]

        for (sentence, appleSentence) in zip(plan.sentences, apple.sentences) {
            let appleWords = WordAlignment.align(
                intended: sentence.words,
                produced: AppleBaselineResults.words(in: appleSentence.text)
            )
            let keyVoxWords = try typer.type(sentence)
            for (index, intended) in sentence.words.enumerated() {
                let appleWord = appleWords[index] ?? ""
                let keyVoxWord = keyVoxWords[index].outcome.finalWord.lowercased()
                let appleIsCorrect = appleWord == intended
                let keyVoxIsCorrect = keyVoxWord == intended
                total += 1
                appleCorrect += appleIsCorrect ? 1 : 0
                keyVoxCorrect += keyVoxIsCorrect ? 1 : 0
                bothCorrect += appleIsCorrect && keyVoxIsCorrect ? 1 : 0
                if appleIsCorrect != keyVoxIsCorrect || appleIsCorrect == false {
                    rows.append([
                        intended,
                        appleWord.isEmpty ? "-" : appleWord,
                        keyVoxWord,
                        keyVoxWords[index].outcome.typedWord,
                        sentence.words[..<index].suffix(3).joined(separator: " "),
                    ].joined(separator: "\t"))
                }
            }
        }

        let lines = [
            "Apple vs KeyVox on identical planned taps",
            "  Apple keyboard: \(apple.device), iOS \(apple.systemVersion)",
            "  sentences: \(plan.sentences.count)   words: \(total)"
                + "   noise: \(plan.noiseInKeyPitches) key pitches",
            "",
            "  Apple final words correct:   \(percent(appleCorrect, total))",
            "  KeyVox final words correct:  \(percent(keyVoxCorrect, total))",
            "  both correct:                \(percent(bothCorrect, total))",
            "  only Apple correct:          \(percent(appleCorrect - bothCorrect, total))",
            "  only KeyVox correct:         \(percent(keyVoxCorrect - bothCorrect, total))",
            "",
        ]
        print(lines.joined(separator: "\n"))
        if let path = options.disagreementsPath {
            try (rows.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
            print("Disagreements written to \(path)")
        }
    }

    private static func percent(_ count: Int, _ total: Int) -> String {
        String(format: "%.1f%%  (%d/%d)", EvaluationReport.rate(count, of: total) * 100, count, total)
    }
}
