import Foundation
import KeyVoxPredictiveKeyboard

/// `bars`: for each probe, types its context words and the first letters of a word through
/// the shipping KeyVox typing session, every tap at its key's center, and records the
/// suggestion bar, in the format the Apple keyboard baseline runner records bars in. A probe
/// with `text` instead reads the bar for that text before the cursor, punctuation included.
enum BarsCommand {
    struct Probe: Codable {
        let context: [String]
        let prefix: String
        let text: String?
        var bar: [String]?
    }

    static func run(_ options: HarnessCommand.BarsOptions) throws {
        var probes = try JSONDecoder().decode(
            [Probe].self,
            from: Data(contentsOf: URL(fileURLWithPath: options.probesPath))
        )
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
            contestedTaps: ContestedTapPolicy(parameters: ContestedTapPolicy.standardParameters)
        )
        for index in probes.indices {
            let bar: SuggestionBar
            if let text = probes[index].text {
                let request = PredictiveTypingSession().request(textBeforeCursor: text + probes[index].prefix)
                bar = try computer.compute(request).bar
            } else {
                bar = try typer.bar(afterTyping: probes[index].context, prefix: probes[index].prefix)
            }
            probes[index].bar = bar.items.map(\.text)
        }
        try JSONEncoder().encode(probes).write(to: URL(fileURLWithPath: options.outputPath))
        print("\(probes.count) bars written to \(options.outputPath)")
    }
}
