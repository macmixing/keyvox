import Foundation

/// The key some of Apple's letter layouts draw beside the letters for accents and the apostrophe,
/// as Apple's keyboard drives it in a typing language whose `language.json` describes it. After a
/// letter one of the key's marks goes on, the key shows that mark and puts it on the letter when it
/// makes the word one the dictionary knows, the likeliest when several do; otherwise it is the
/// apostrophe when the word and an apostrophe begin words the dictionary knows other than names,
/// as an elided word does, and otherwise the language's usual mark for the letter. After any other letter it is the
/// apostrophe, and with no letter before the cursor it types its own character.
public struct AccentKey: Sendable {
    /// What the key asks the dictionary.
    public struct Dictionary {
        /// How likely a word is, or nil for a word the dictionary does not know.
        public let wordProbability: (String) -> Double?
        /// Whether some word the dictionary knows, other than a name, begins with the given letters.
        public let beginsWords: (String) -> Bool

        public init(wordProbability: @escaping (String) -> Double?, beginsWords: @escaping (String) -> Bool) {
            self.wordProbability = wordProbability
            self.beginsWords = beginsWords
        }
    }

    /// The character the layout draws on the key.
    public let character: String
    /// Each mark the key or its popup can put on a letter, with the combining mark that does it.
    private let combiningMarks: [String: String]
    /// The marks the key itself can show, in the order a tie between them is settled.
    private let keyMarks: [String]
    /// The mark the key shows after each lowercase letter when no mark makes a known word.
    private let usualMarks: [String: String]

    init(manifest: TypingLanguageManifest.AccentKey) {
        character = manifest.character
        combiningMarks = manifest.combiningMarks
        keyMarks = manifest.keyMarks
        usualMarks = manifest.usualMarks
    }

    /// Whether `text` is one of the marks the key or its popup puts on letters.
    public func isMark(_ text: String) -> Bool {
        combiningMarks[text] != nil
    }

    /// What the key shows and types after `textBeforeCursor`: one of its marks, the apostrophe,
    /// or its own character.
    /// - Parameter dictionary: The language's dictionary, or nil when none is at hand, which
    ///   leaves the usual marks.
    public func mark(after textBeforeCursor: String?, dictionary: Dictionary? = nil) -> String {
        guard let letter = textBeforeCursor?.last, letter.isLetter else { return character }
        if let dictionary {
            let word = TypingTextContext(textBeforeCursor: textBeforeCursor).currentWord
            let known = keyMarks.compactMap { mark -> (mark: String, probability: Double)? in
                guard let marked = marked(letter, with: mark),
                      let probability = dictionary.wordProbability(word.dropLast() + marked) else {
                    return nil
                }
                return (mark, probability)
            }
            if let best = known.max(by: { $0.probability < $1.probability }) {
                return best.mark
            }
            if dictionary.beginsWords(word + Self.dictionaryApostrophe) {
                return SmartQuotes.apostrophe
            }
        }
        if let usual = usualMarks[letter.lowercased()], marked(letter, with: usual) != nil {
            return usual
        }
        return SmartQuotes.apostrophe
    }

    /// The edit putting `mark` on the letter right before the cursor, or nil when there is none
    /// or the mark does not go on it, as after a digit, where the mark is typed as it is.
    public func edit(placing mark: String, after textBeforeCursor: String?) -> TextEdit? {
        guard let letter = textBeforeCursor?.last, letter.isLetter, let marked = marked(letter, with: mark) else {
            return nil
        }
        return TextEdit(deleteCount: 1, insertText: marked)
    }

    /// The apostrophe as the dictionary writes it inside words.
    private static let dictionaryApostrophe = "'"

    /// `letter` with `mark` on it as one precomposed letter, or nil when Unicode has none.
    private func marked(_ letter: Character, with mark: String) -> String? {
        guard let combining = combiningMarks[mark] else { return nil }
        let composed = (String(letter) + combining).precomposedStringWithCanonicalMapping
        return composed.unicodeScalars.count == 1 ? composed : nil
    }
}
