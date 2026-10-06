import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// `explain`: runs one typed word with exact touches and context through the shipping
/// prediction path and prints every candidate's scores, to see why a decision happened.
enum ExplainCommand {
    static func run(_ options: HarnessCommand.ExplainOptions) throws {
        let setup = try EngineSetup()
        let computer = PredictionComputer(engine: setup.engine, parameters: options.parameters)
        computer.updateKeyboardGeometry(
            setup.layout.predictionGeometry,
            keyboardSize: setup.layout.keyboardSize
        )
        let session = PredictiveTypingSession()
        var text = options.previousWords.reversed().joined(separator: " ")
        if text.isEmpty == false { text.append(" ") }
        for (index, letter) in options.typedWord.enumerated() {
            text.append(letter)
            if options.touches.indices.contains(index) {
                session.recordTap(at: options.touches[index], textBeforeCursor: text)
            }
        }
        let request = session.request(textBeforeCursor: text)
        let result = try computer.compute(request)
        print(String(
            format: "engine load added %.1f MB; process footprint now %.1f MB",
            MemoryFootprint.megabytes(setup.startupFootprintBytes),
            MemoryFootprint.megabytes(MemoryFootprint.current())
        ))
        print("request word=\(request.currentWord) previous=\(request.previousWords) touches=\(request.touches.count)")
        print("autocorrection: \(result.autocorrection ?? "none")")
        print("bar: \(result.bar.items.map { "\($0.text) (\($0.kind))" })")

        let response = try setup.engine.predict(
            typedWord: request.currentWord,
            previousWords: request.previousWords,
            touches: request.touches.map(PredictionTouch.init(location:)),
            mode: .correction
        )
        let corrector = NoisyChannelCorrector(
            parameters: options.parameters,
            keys: setup.keys,
            language: setup.language
        )
        let decision = try corrector.decide(
            typedWord: request.currentWord,
            touches: request.touches,
            previousWords: request.previousWords,
            candidates: response.suggestions.map(\.word)
        )
        print("engine candidates: \(response.suggestions.map(\.word))")
        for candidate in [decision.typed] + decision.rankedAlternatives {
            print(String(
                format: "  %-14@ score %8.3f  touch %7.3f  logP %8.3f  dictionary %@",
                candidate.word as NSString,
                candidate.score,
                candidate.touchCost,
                candidate.language.logProbability,
                candidate.language.isDictionaryWord ? "yes" : "no"
            ))
        }
    }
}
