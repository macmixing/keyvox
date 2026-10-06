import KeyVoxPredictiveKeyboard

/// Types a planned sentence through the shipping typing session, letter by letter,
/// requesting suggestions after every letter and pressing space after each word, and
/// applies every edit to a text buffer, exactly as a keyboard host does.
struct SessionTyper {
    let computer: PredictionComputer
    let layout: KeyboardLayoutModel

    func type(_ sentence: TypingPlan.Sentence) throws -> String {
        let session = PredictiveTypingSession()
        var text = ""
        for (word, offsets) in zip(sentence.words, sentence.taps) {
            let typing = SimulatedTyping(
                tappedWord: word,
                offsetsInKeyPitches: offsets,
                layout: layout
            )
            var result: PredictionResult?
            for (letter, touch) in zip(typing.typedWord, typing.touches) {
                text.append(letter)
                session.recordTap(at: touch.location, textBeforeCursor: text)
                result = try computer.compute(session.request(textBeforeCursor: text))
            }
            Self.apply(
                session.wordBoundaryEdit(separator: " ", textBeforeCursor: text, result: result),
                to: &text
            )
            _ = try computer.compute(session.request(textBeforeCursor: text))
        }
        return text
    }

    static func apply(_ edit: TextEdit, to text: inout String) {
        text.removeLast(min(edit.deleteCount, text.count))
        text.append(edit.insertText)
    }
}
