import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// `explain`: runs one typed word with exact touches and context, and optionally the
/// user's own words, through the shipping prediction path and prints every candidate's
/// scores, to see why a decision happened. With no typed word it shows the next-word bar;
/// with a following word it shows how the typed word is reconsidered once that word is known.
enum ExplainCommand {
    static func run(_ options: HarnessCommand.ExplainOptions) throws {
        let setup = try EngineSetup()
        let computer = PredictionComputer(engine: setup.engine, parameters: options.parameters)
        computer.updateKeyboardGeometry(
            setup.layout.predictionGeometry,
            keyboardSize: setup.layout.keyboardSize
        )
        let footprintBeforePersonalWords = MemoryFootprint.current()
        let vocabulary = PersonalVocabulary(words: options.personalWords, textReplacements: [])
        try computer.updateVocabulary(vocabulary)
        let personalWordsFootprintBytes = MemoryFootprint.current() &- footprintBeforePersonalWords
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
            format: "engine load added %.1f MB; %d personal words added %.2f MB; process footprint now %.1f MB",
            MemoryFootprint.megabytes(setup.startupFootprintBytes),
            vocabulary.words.count,
            MemoryFootprint.megabytes(personalWordsFootprintBytes),
            MemoryFootprint.megabytes(MemoryFootprint.current())
        ))
        print("request word=\(request.currentWord) previous=\(request.previousWords) touches=\(request.touches.count)")
        print("autocorrection: \(result.autocorrection ?? "none")")
        print("bar: \(result.bar.items.map { "\($0.text) (\($0.kind))" })")
        guard request.currentWord.isEmpty == false else { return }

        let response = try setup.engine.predict(
            typedWord: request.currentWord,
            previousWords: request.previousWords,
            touches: request.touches.map(PredictionTouch.init(location:)),
            mode: .correction
        )
        let personalCandidates = try setup.engine.personalSuggestions(
            typedWord: request.currentWord,
            touches: request.touches.map(PredictionTouch.init(location:))
        )
        let corrector = NoisyChannelCorrector(
            parameters: options.parameters,
            keys: setup.keys,
            language: ContextLanguageScorer(engine: setup.engine, vocabulary: vocabulary)
        )
        let decision = try corrector.decide(
            typedWord: request.currentWord,
            touches: request.touches,
            previousWords: request.previousWords,
            followingWord: options.followingWord,
            candidates: response.suggestions.map(\.word) + personalCandidates
        )
        if let followingWord = options.followingWord {
            let revision = try computer.revision(for: RevisionRequest(
                word: request.currentWord,
                touches: request.touches,
                previousWords: request.previousWords,
                followingWord: followingWord
            ))
            print("revision before \(followingWord): \(revision ?? "none")")
        }
        print("engine candidates: \(response.suggestions.map(\.word))")
        print("personal candidates: \(personalCandidates)")
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
