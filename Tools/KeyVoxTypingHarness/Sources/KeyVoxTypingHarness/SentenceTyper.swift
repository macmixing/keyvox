import Foundation
import KeyVoxPredictiveKeyboard

/// Types one planned sentence word by word through KeyVox's correction path, feeding
/// each word's final form back in as context for the next word, as a real text field would.
struct SentenceTyper {
    struct TypedWord {
        let typing: SimulatedTyping
        let outcome: CorrectionOutcome
        let milliseconds: Double
    }

    let setup: EngineSetup
    let parameters: NoisyChannelCorrector.Parameters
    let usesTouches: Bool

    func type(_ sentence: TypingPlan.Sentence) throws -> [TypedWord] {
        let correction = setup.correctionEvaluator(parameters: parameters)
        var finalWords: [String] = []
        var typedWords: [TypedWord] = []
        for (index, (word, offsets)) in zip(sentence.words, sentence.taps).enumerated() {
            let typing = SimulatedTyping(
                tappedWord: word,
                offsetsInKeyPitches: offsets,
                layout: setup.layout
            )
            let previousWords = Array(finalWords.reversed().prefix(3))
            let started = ContinuousClock.now
            let outcome = try correction.evaluate(
                intendedWord: sentence.truthWords[index],
                typing: typing,
                previousWords: previousWords,
                usesTouches: usesTouches
            )
            typedWords.append(TypedWord(
                typing: typing,
                outcome: outcome,
                milliseconds: EngineSetup.milliseconds(since: started)
            ))
            finalWords.append(outcome.finalWord.lowercased())
        }
        return typedWords
    }
}
