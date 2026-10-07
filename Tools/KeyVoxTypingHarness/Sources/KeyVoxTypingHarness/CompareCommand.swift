import Foundation
import KeyVoxPredictiveKeyboard

/// `compare`: types the plan through the shipping KeyVox typing session, optionally with
/// the user's own words loaded, and scores it word for word, against what the Apple
/// keyboard produced from the same planned taps when Apple results are given.
enum CompareCommand {
    static func run(_ options: HarnessCommand.CompareOptions) throws {
        let plan = try TypingPlan.load(from: options.planPath)
        let apple = try options.appleResultsPath.map(AppleBaselineResults.load(from:))
        if let apple, apple.sentences.count > plan.sentences.count {
            throw HarnessError.planMismatch(
                "\(apple.sentences.count) Apple sentences for \(plan.sentences.count) planned"
            )
        }
        let setup = try EngineSetup()
        let computer = PredictionComputer(engine: setup.engine, parameters: options.parameters)
        computer.updateKeyboardGeometry(
            setup.layout.predictionGeometry,
            keyboardSize: setup.layout.keyboardSize
        )
        try computer.updateVocabulary(PersonalVocabulary(
            words: options.personalWords,
            knownNames: options.knownNames,
            textReplacements: []
        ))
        let typer = SessionTyper(
            computer: computer,
            layout: setup.layout,
            contestedTaps: options.contestedTaps.map(ContestedTapPolicy.init(parameters:))
        )

        var total = 0
        var appleCorrect = 0
        var keyVoxCorrect = 0
        var bothCorrect = 0
        var rows = ["intended\tapple\tkeyvox\tprevious"]
        var texts: [AppleBaselineResults.Sentence] = []

        let sentences = plan.sentences.prefix(apple?.sentences.count ?? plan.sentences.count)
        for (sentenceIndex, sentence) in sentences.enumerated() {
            let appleWords = apple.map {
                WordAlignment.align(
                    intended: sentence.truthWords,
                    produced: AppleBaselineResults.words(in: $0.sentences[sentenceIndex].text)
                )
            }
            let typed = try typer.type(sentence)
            texts.append(AppleBaselineResults.Sentence(text: typed))
            let keyVoxWords = WordAlignment.align(
                intended: sentence.truthWords,
                produced: AppleBaselineResults.words(in: typed)
            )
            for (index, intended) in sentence.truthWords.enumerated() {
                let appleWord = appleWords?[index] ?? ""
                let keyVoxWord = keyVoxWords[index] ?? ""
                let appleIsCorrect = appleWord == intended
                let keyVoxIsCorrect = keyVoxWord == intended
                total += 1
                appleCorrect += appleIsCorrect ? 1 : 0
                keyVoxCorrect += keyVoxIsCorrect ? 1 : 0
                bothCorrect += appleIsCorrect && keyVoxIsCorrect ? 1 : 0
                if appleIsCorrect == false || keyVoxIsCorrect == false {
                    rows.append([
                        intended,
                        appleWord.isEmpty ? "-" : appleWord,
                        keyVoxWord.isEmpty ? "-" : keyVoxWord,
                        sentence.truthWords[..<index].suffix(3).joined(separator: " "),
                    ].joined(separator: "\t"))
                }
            }
        }

        var lines = [
            apple == nil ? "KeyVox on planned taps" : "Apple vs KeyVox on identical planned taps",
        ]
        if let apple {
            lines.append(
                "  simulator keyboard: \(apple.keyboard ?? "System") on \(apple.device), iOS \(apple.systemVersion)"
            )
        }
        lines += [
            "  sentences: \(sentences.count)   words: \(total)"
                + "   noise: \(plan.noiseInKeyPitches) key pitches",
            "",
        ]
        if apple != nil {
            lines.append("  Apple final words correct:   \(percent(appleCorrect, total))")
        }
        lines.append("  KeyVox final words correct:  \(percent(keyVoxCorrect, total))")
        if apple != nil {
            lines += [
                "  both correct:                \(percent(bothCorrect, total))",
                "  only Apple correct:          \(percent(appleCorrect - bothCorrect, total))",
                "  only KeyVox correct:         \(percent(keyVoxCorrect - bothCorrect, total))",
            ]
        }
        lines.append("")
        print(lines.joined(separator: "\n"))
        if let path = options.textsPath {
            let results = AppleBaselineResults(device: "harness", systemVersion: "", keyboard: "KeyVox", sentences: texts)
            try JSONEncoder().encode(results).write(to: URL(fileURLWithPath: path))
        }
        if let path = options.disagreementsPath {
            try (rows.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
            print("Disagreements written to \(path)")
        }
    }

    private static func percent(_ count: Int, _ total: Int) -> String {
        String(format: "%.1f%%  (%d/%d)", EvaluationReport.rate(count, of: total) * 100, count, total)
    }
}
