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
    let typingLanguage: TypingLanguage
    let layout: KeyboardLayoutModel
    /// Resolves taps that land on another key just past a letter; nil keeps every key hit.
    let contestedTaps: ContestedTapPolicy?

    func type(_ sentence: TypingPlan.Sentence) throws -> String {
        let session = PredictiveTypingSession(language: typingLanguage)
        var text = ""
        for (word, offsets) in zip(sentence.words, sentence.taps) {
            try typeLetters(of: word, offsets: offsets, session: session, text: &text)
            try press(.space, at: .zero, session: session, text: &text)
        }
        return text
    }

    /// The suggestion bar after typing each word of `context` and a space, then the letters
    /// of `prefix`, every tap at its key's center.
    func bar(afterTyping context: [String], prefix: String) throws -> SuggestionBar {
        let session = PredictiveTypingSession(language: typingLanguage)
        var text = ""
        for word in context {
            try typeLetters(of: word, offsets: centered(word), session: session, text: &text)
            try press(.space, at: .zero, session: session, text: &text)
        }
        try typeLetters(of: prefix, offsets: centered(prefix), session: session, text: &text)
        return try computer.compute(session.request(textBeforeCursor: text)).bar
    }

    private func centered(_ word: String) -> [[Double]] {
        Array(repeating: [0, 0], count: word.filter { $0 != "'" }.count)
    }

    private func typeLetters(
        of word: String,
        offsets: [[Double]],
        session: PredictiveTypingSession,
        text: inout String
    ) throws {
        for (letter, offset) in zip(word.filter { $0 != "'" }, offsets) {
            guard let center = layout.center(of: letter) else { continue }
            // A letter only a held popup offers is picked from it, exactly.
            if layout.popupLetters[letter] != nil {
                try press(.letter(letter), at: center, session: session, text: &text)
                continue
            }
            let touch = CGPoint(
                x: center.x + offset[0] * layout.keyPitch.width,
                y: center.y + offset[1] * layout.keyPitch.height
            )
            guard let (key, frame) = layout.key(at: touch) else { continue }
            let resolved = try resolve(key, frame: frame, at: touch, session: session, text: text)
            try press(resolved, at: touch, session: session, text: &text)
        }
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
        case .accentKey: otherKey = .accentKey
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
        case .accentKey:
            try pressAccentKey(at: touch, session: session, text: &text)
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
            if text.isEmpty == false {
                text.removeLast()
                session.textDidChange(textBeforeCursor: text)
            }
        case .shift, .numbers:
            return
        }
        _ = try computer.compute(session.request(textBeforeCursor: text))
    }

    /// Types what the language's accent key shows after `text`, as the keyboard does: its mark
    /// put on the letter before the cursor, or the apostrophe or the mark itself after it. As on
    /// the keyboard, a character that belongs inside a word (`TypingTextRules.isWordCharacter`),
    /// the apostrophe, records its tap, so the word's taps keep lining up with its characters;
    /// the mark put on a letter or typed on its own changes the text without one.
    private func pressAccentKey(at touch: CGPoint, session: PredictiveTypingSession, text: inout String) throws {
        guard let accentKey = typingLanguage.accentKey else { return }
        let mark = computer.accentKeyMark(after: text) ?? accentKey.character
        if let edit = accentKey.edit(placing: mark, after: text) {
            Self.apply(edit, to: &text)
            session.textDidChange(textBeforeCursor: text)
            return
        }
        let typed = typingLanguage.quotes.text(for: mark, after: text)
        text.append(typed)
        if typed.count == 1, let character = typed.first, typingLanguage.textRules.isWordCharacter(character) {
            session.recordTap(at: touch, textBeforeCursor: text)
        } else {
            session.textDidChange(textBeforeCursor: text)
        }
    }

    static func apply(_ edit: TextEdit, to text: inout String) {
        text.removeLast(min(edit.deleteCount, text.count))
        text.append(edit.insertText)
    }
}
