import CoreGraphics
import KeyVoxPredictiveKeyboard

/// Types a planned sentence through the shipping typing session the way the keyboard
/// does: every planned tap lands on whichever key it hits (a letter, or shift, delete,
/// 123, space, or return), a tap on another key close to a letter is resolved the way the
/// keyboard resolves it, suggestions are requested after every key, and the space after
/// each word is tapped at the space bar's center. Edits are applied to a text buffer
/// exactly as a keyboard host applies them.
struct SessionTyper {
    let computer: PredictionComputer
    let layout: KeyboardLayoutModel
    /// Resolves taps that land on another key just past a letter; nil keeps every key hit.
    let contestedTaps: ContestedTapPolicy?

    func type(_ sentence: TypingPlan.Sentence) throws -> String {
        let session = PredictiveTypingSession()
        var text = ""
        for (word, offsets) in zip(sentence.words, sentence.taps) {
            for (letter, offset) in zip(word.filter { $0 != "'" }, offsets) {
                guard let center = layout.center(of: letter) else { continue }
                let touch = CGPoint(
                    x: center.x + offset[0] * layout.keyPitch.width,
                    y: center.y + offset[1] * layout.keyPitch.height
                )
                guard let (key, frame) = layout.key(at: touch) else { continue }
                let resolved = try resolve(key, frame: frame, at: touch, session: session, text: text)
                try press(resolved, at: touch, session: session, text: &text)
            }
            try press(.space, at: .zero, session: session, text: &text)
        }
        return text
    }

    private func resolve(
        _ key: KeyboardLayoutModel.Key,
        frame: CGRect,
        at touch: CGPoint,
        session: PredictiveTypingSession,
        text: String
    ) throws -> KeyboardLayoutModel.Key {
        let otherKey: ContestedTap.OtherKey
        switch key {
        case .letter: return key
        case .space, .returnKey: otherKey = .wordBoundary
        case .shift, .delete, .numbers: otherKey = .control
        }
        guard let contestedTaps,
              let letter = try computer.intendedLetter(
                  forTapAt: touch,
                  onKeyWithFrame: frame,
                  otherKey: otherKey,
                  request: session.request(textBeforeCursor: text),
                  policy: contestedTaps
              ) else {
            return key
        }
        return .letter(letter)
    }

    private func press(
        _ key: KeyboardLayoutModel.Key,
        at touch: CGPoint,
        session: PredictiveTypingSession,
        text: inout String
    ) throws {
        switch key {
        case .letter(let letter):
            text.append(letter)
            session.recordTap(at: touch, textBeforeCursor: text)
        case .space, .returnKey:
            let separator = key == .space ? " " : "\n"
            let result = try computer.compute(session.request(textBeforeCursor: text))
            let revision = try session.revisionRequest(textBeforeCursor: text, result: result)
                .flatMap(computer.revision(for:))
            Self.apply(
                session.wordBoundaryEdit(
                    separator: separator,
                    textBeforeCursor: text,
                    result: result,
                    revision: revision
                ),
                to: &text
            )
        case .delete:
            if let edit = session.backspaceEdit(textBeforeCursor: text) {
                Self.apply(edit, to: &text)
            } else if text.isEmpty == false {
                text.removeLast()
                session.textDidChange(textBeforeCursor: text)
            }
        case .shift, .numbers:
            return
        }
        _ = try computer.compute(session.request(textBeforeCursor: text))
    }

    static func apply(_ edit: TextEdit, to text: inout String) {
        text.removeLast(min(edit.deleteCount, text.count))
        text.append(edit.insertText)
    }
}
