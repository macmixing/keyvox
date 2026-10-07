/// Words and shortcuts that belong to this user.
///
/// Entries from their KeyVox Dictionary are suggested and corrected toward like the bundled
/// dictionary's words and are never autocorrected away; the words of an entry phrase predict
/// each other in order, and `PersonalWordForms` decides when they take the entry's
/// capitals. Names the system knows, such as contacts, are only left as typed: they are
/// never suggested and never change how another word is written. Text replacement shortcuts
/// expand at the end of a word.
public struct PersonalVocabulary: Sendable, Equatable {
    public struct TextReplacement: Sendable, Equatable {
        public let shortcut: String
        public let expansion: String

        public init(shortcut: String, expansion: String) {
            self.shortcut = shortcut
            self.expansion = expansion
        }
    }

    /// Two words that follow each other in an entry phrase.
    private struct PhrasePair: Hashable, Sendable {
        let first: String
        let second: String
    }

    public static let empty = PersonalVocabulary(words: [], textReplacements: [])

    /// Lowercased word to its form in the first entry that has it, for every entry word.
    private let entryFormsByKey: [String: String]
    /// Lowercased word to its form, for entries that are a single word.
    private let singleWordEntryFormsByKey: [String: String]
    /// Consecutive words of entry phrases, keyed in lowercase, to how the phrase writes them.
    private let phrasePairForms: [PhrasePair: PhrasePair]
    /// Lowercased word to the words that follow it in entry phrases, as written.
    private let continuationsByKey: [String: [String]]
    /// Lowercased names the system knows, such as contacts.
    private let knownNameKeys: Set<String>
    /// Lowercased shortcut to its expansion.
    private let expansionsByShortcut: [String: String]

    /// - Parameters:
    ///   - words: KeyVox Dictionary entries, single words or phrases; each word of a phrase
    ///     counts on its own and predicts the word after it.
    ///   - knownNames: Names the system knows, such as contact names, which are left as
    ///     typed and nothing more.
    ///   - textReplacements: Shortcuts and what they expand to.
    public init(words: [String], knownNames: [String] = [], textReplacements: [TextReplacement]) {
        var entryForms: [String: String] = [:]
        var singleWordEntryForms: [String: String] = [:]
        var pairForms: [PhrasePair: PhrasePair] = [:]
        var continuations: [String: [String]] = [:]
        for phrase in words {
            let phraseWords = Self.words(in: phrase)
            if phraseWords.count == 1, let word = phraseWords.first {
                singleWordEntryForms[Self.key(word)] = singleWordEntryForms[Self.key(word)] ?? word
            }
            for word in phraseWords {
                entryForms[Self.key(word)] = entryForms[Self.key(word)] ?? word
            }
            for (word, next) in zip(phraseWords, phraseWords.dropFirst()) {
                let pair = PhrasePair(first: Self.key(word), second: Self.key(next))
                pairForms[pair] = pairForms[pair] ?? PhrasePair(first: word, second: next)
                if continuations[Self.key(word), default: []].contains(next) == false {
                    continuations[Self.key(word), default: []].append(next)
                }
            }
        }
        var expansions: [String: String] = [:]
        for replacement in textReplacements where replacement.shortcut.isEmpty == false {
            let shortcut = Self.key(replacement.shortcut)
            if shortcut != Self.key(replacement.expansion) {
                expansions[shortcut] = replacement.expansion
            }
        }
        entryFormsByKey = entryForms
        singleWordEntryFormsByKey = singleWordEntryForms
        phrasePairForms = pairForms
        continuationsByKey = continuations
        knownNameKeys = Set(knownNames.flatMap(Self.words(in:)).map(Self.key))
        expansionsByShortcut = expansions
    }

    public var isEmpty: Bool {
        entryFormsByKey.isEmpty && knownNameKeys.isEmpty && expansionsByShortcut.isEmpty
    }

    /// Every word of every entry, as written there.
    public var words: [String] {
        entryFormsByKey.values.sorted()
    }

    /// The words of entry phrases, as written there.
    public var phraseWords: [String] {
        Set(phrasePairForms.values.flatMap { [$0.first, $0.second] }).sorted()
    }

    /// Whether `word` is a word of one of the user's entries.
    public func contains(_ word: String) -> Bool {
        entryFormsByKey[Self.key(word)] != nil
    }

    /// Whether `word`, typed in full, must be left as typed: an entry word or a known name.
    public func keepsAsTyped(_ word: String) -> Bool {
        contains(word) || knownNameKeys.contains(Self.key(word))
    }

    /// How an entry writes `word`, if it is an entry word.
    public func entryForm(of word: String) -> String? {
        entryFormsByKey[Self.key(word)]
    }

    /// How the user writes `word`, if it is an entry on its own.
    public func singleWordEntryForm(of word: String) -> String? {
        singleWordEntryFormsByKey[Self.key(word)]
    }

    /// How an entry phrase writes `word` right after `previousWord`, if it has them in a row.
    public func phraseForm(of word: String, after previousWord: String) -> String? {
        phrasePairForms[PhrasePair(first: Self.key(previousWord), second: Self.key(word))]?.second
    }

    /// How an entry phrase writes `word` right before `nextWord`, if it has them in a row.
    public func phraseForm(of word: String, before nextWord: String) -> String? {
        phrasePairForms[PhrasePair(first: Self.key(word), second: Self.key(nextWord))]?.first
    }

    public func expansion(for typedWord: String) -> String? {
        expansionsByShortcut[Self.key(typedWord)]
    }

    /// The words that follow `previousWord` in the user's phrases, as written.
    public func continuations(after previousWord: String) -> [String] {
        continuationsByKey[Self.key(previousWord)] ?? []
    }

    /// Whether `word` follows `previousWord` in one of the user's phrases.
    public func continues(_ previousWord: String, with word: String) -> Bool {
        phraseForm(of: word, after: previousWord) != nil
    }

    /// The form personal words are compared in: lowercase, with a straight apostrophe.
    static func key(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    private static func words(in phrase: String) -> [String] {
        phrase.split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { $0.contains(where: \.isLetter) }
    }
}
