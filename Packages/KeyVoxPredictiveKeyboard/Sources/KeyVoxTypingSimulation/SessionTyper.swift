import CoreGraphics
import KeyVoxPredictiveKeyboard

/// Types a planned sentence through the shipping typing session the way the keyboard
/// does: every planned tap lands on whichever key it hits (a letter, or shift, delete,
/// 123, space, or return), a tap on another key close to a letter is resolved the way the
/// keyboard resolves it, suggestions are requested after every key, and the space after
/// each word is tapped at the space bar's center. Edits are applied to a text buffer
/// exactly as a keyboard host applies them.
///
/// Apostrophes are not tapped, matching how people type contractions on a letter page and
/// rely on autocorrect to restore them.
public struct SessionTyper {
    /// A moment while typing a sentence: after `letters` taps of the word at index `word`, or,
    /// with no letters, after the space before it (before the first key, for the first word).
    public struct BarPoint: Codable, Equatable, Sendable {
        public let word: Int
        public let letters: Int

        public init(word: Int, letters: Int) {
            self.word = word
            self.letters = letters
        }
    }

    /// The text a typed sentence left, and the suggestion bar at each point asked for.
    public struct TypedSentence {
        public let text: String
        /// In the order the points were asked for.
        public let bars: [SuggestionBar]
    }

    public enum TypingError: Error, Equatable {
        /// The sentence has no such word, or the word has fewer taps.
        case barPointNotReached(BarPoint)
    }

    public let computer: PredictionComputer
    public let typingLanguage: TypingLanguage
    public let layout: KeyboardLayoutModel
    /// Resolves taps that land on another key just past a letter; nil keeps every key hit.
    public let contestedTaps: ContestedTapPolicy?

    public init(
        computer: PredictionComputer,
        typingLanguage: TypingLanguage,
        layout: KeyboardLayoutModel,
        contestedTaps: ContestedTapPolicy?
    ) {
        self.computer = computer
        self.typingLanguage = typingLanguage
        self.layout = layout
        self.contestedTaps = contestedTaps
    }

    /// Types `words`, each letter tapped at its key's center plus its offset in `taps`
    /// (per word, per tapped letter, `[dx, dy]` in key pitches), with a space after each word.
    public func type(
        words: [String],
        taps: [[[Double]]],
        barsAt points: [BarPoint] = []
    ) throws -> TypedSentence {
        let session = PredictiveTypingSession(language: typingLanguage)
        var text = ""
        var bars = [SuggestionBar?](repeating: nil, count: points.count)
        var latestBar: SuggestionBar?
        func capture(word: Int, letters: Int) throws {
            for (index, point) in points.enumerated() where point == BarPoint(word: word, letters: letters) {
                if latestBar == nil {
                    latestBar = try computer.compute(session.request(textBeforeCursor: text)).bar
                }
                bars[index] = latestBar
            }
        }
        for (wordIndex, (word, offsets)) in zip(words, taps).enumerated() {
            try capture(word: wordIndex, letters: 0)
            for (letterIndex, (letter, offset)) in zip(word.filter { $0 != "'" }, offsets).enumerated() {
                if let bar = try tap(letter, offset: offset, session: session, text: &text) {
                    latestBar = bar
                }
                try capture(word: wordIndex, letters: letterIndex + 1)
            }
            latestBar = try press(.space, at: .zero, session: session, text: &text)
        }
        return TypedSentence(text: text, bars: try zip(points, bars).map { point, bar in
            guard let bar else { throw TypingError.barPointNotReached(point) }
            return bar
        })
    }

    /// The suggestion bar after typing each word of `context` and a space, then the letters
    /// of `prefix`, every tap at its key's center.
    public func bar(afterTyping context: [String], prefix: String) throws -> SuggestionBar {
        let session = PredictiveTypingSession(language: typingLanguage)
        var text = ""
        for word in context {
            try typeLetters(of: word, session: session, text: &text)
            try press(.space, at: .zero, session: session, text: &text)
        }
        try typeLetters(of: prefix, session: session, text: &text)
        return try computer.compute(session.request(textBeforeCursor: text)).bar
    }

    private func typeLetters(of word: String, session: PredictiveTypingSession, text: inout String) throws {
        for letter in word.filter({ $0 != "'" }) {
            try tap(letter, offset: [0, 0], session: session, text: &text)
        }
    }

    /// Taps `letter`'s key `offset` key pitches from its center, returning the suggestion bar
    /// after the key it hit, or nil when no key types the letter or the tap misses the keyboard.
    @discardableResult
    private func tap(
        _ letter: Character,
        offset: [Double],
        session: PredictiveTypingSession,
        text: inout String
    ) throws -> SuggestionBar? {
        guard let center = layout.center(of: letter) else { return nil }
        let touch = CGPoint(
            x: center.x + offset[0] * layout.keyPitch.width,
            y: center.y + offset[1] * layout.keyPitch.height
        )
        guard let (key, frame) = layout.key(at: touch) else { return nil }
        let resolved = try resolve(key, frame: frame, at: touch, session: session, text: text)
        return try press(resolved, at: touch, session: session, text: &text)
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

    /// Presses `key` and returns the suggestion bar after it.
    @discardableResult
    private func press(
        _ key: KeyboardLayoutModel.Key,
        at touch: CGPoint,
        session: PredictiveTypingSession,
        text: inout String
    ) throws -> SuggestionBar? {
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
            if text.isEmpty == false {
                text.removeLast()
                session.textDidChange(textBeforeCursor: text)
            }
        case .shift, .numbers:
            return nil
        }
        return try computer.compute(session.request(textBeforeCursor: text)).bar
    }

    static func apply(_ edit: TextEdit, to text: inout String) {
        text.removeLast(min(edit.deleteCount, text.count))
        text.append(edit.insertText)
    }
}
