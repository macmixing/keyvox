import KeyVoxPredictiveKeyboard

/// Types a planned sentence through the shipping typing session, letter by letter,
/// pressing space after each word and applying every edit to a text buffer, exactly as
/// a keyboard host would.
struct SessionTyper {
    let computer: PredictionComputer
    let layout: KeyboardLayoutModel

    func type(_ sentence: TypingPlan.Sentence) throws -> String {
        let session = PredictiveTypingSession()
        var text = ""
        for (word, offsets) in zip(sentence.words, sentence.taps) {
            let typing = SimulatedTyping(
                intendedWord: word,
                offsetsInKeyPitches: offsets,
                layout: layout
            )
            for (letter, touch) in zip(typing.typedWord, typing.touches) {
                text.append(letter)
                session.recordTap(at: touch.location, textBeforeCursor: text)
            }
            let result = try computer.compute(session.request(textBeforeCursor: text))
            Self.apply(session.spaceEdit(textBeforeCursor: text, result: result), to: &text)
        }
        return text
    }

    static func apply(_ edit: TextEdit, to text: inout String) {
        text.removeLast(min(edit.deleteCount, text.count))
        text.append(edit.insertText)
    }
}
