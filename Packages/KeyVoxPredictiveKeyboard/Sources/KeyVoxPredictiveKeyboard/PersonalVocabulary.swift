/// Words and shortcuts that belong to this user: their KeyVox Dictionary, contact names,
/// and text replacements. Personal words are suggested and corrected toward like the
/// bundled dictionary's words, are never autocorrected away, and the words of a personal
/// phrase predict each other in order. Text replacement shortcuts expand at the end of a
/// word.
public struct PersonalVocabulary: Sendable, Equatable {
    public struct TextReplacement: Sendable, Equatable {
        public let shortcut: String
        public let expansion: String

        public init(shortcut: String, expansion: String) {
            self.shortcut = shortcut
            self.expansion = expansion
        }
    }

    public static let empty = PersonalVocabulary(words: [], textReplacements: [])

    /// Lowercased word to the form the user writes it in.
    private let displayFormsByKey: [String: String]
    /// Lowercased word to the words that follow it in the user's phrases, as written.
    private let continuationsByKey: [String: [String]]
    /// Lowercased shortcut to its expansion.
    private let expansionsByShortcut: [String: String]

    /// - Parameters:
    ///   - words: Personal words or phrases; each word of a phrase counts on its own and
    ///     predicts the word after it.
    ///   - textReplacements: Shortcuts and what they expand to.
    public init(words: [String], textReplacements: [TextReplacement]) {
        var displayForms: [String: String] = [:]
        var continuations: [String: [String]] = [:]
        for phrase in words {
            let phraseWords = phrase.split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
                .filter { $0.contains(where: \.isLetter) }
            for word in phraseWords {
                displayForms[Self.key(word)] = displayForms[Self.key(word)] ?? word
            }
            for (word, next) in zip(phraseWords, phraseWords.dropFirst())
            where continuations[Self.key(word), default: []].contains(next) == false {
                continuations[Self.key(word), default: []].append(next)
            }
        }
        var expansions: [String: String] = [:]
        for replacement in textReplacements where replacement.shortcut.isEmpty == false {
            let shortcut = Self.key(replacement.shortcut)
            if shortcut != Self.key(replacement.expansion) {
                expansions[shortcut] = replacement.expansion
            }
        }
        displayFormsByKey = displayForms
        continuationsByKey = continuations
        expansionsByShortcut = expansions
    }

    public var isEmpty: Bool {
        displayFormsByKey.isEmpty && expansionsByShortcut.isEmpty
    }

    /// Every personal word, in the form the user writes it.
    public var words: [String] {
        displayFormsByKey.values.sorted()
    }

    public func contains(_ word: String) -> Bool {
        displayFormsByKey[Self.key(word)] != nil
    }

    /// How the user writes `word`, if it is one of theirs.
    public func displayForm(of word: String) -> String? {
        displayFormsByKey[Self.key(word)]
    }

    /// `words`, with any of the user's own words in the form the user writes them.
    public func writtenForms(of words: [String]) -> [String] {
        words.map { displayForm(of: $0) ?? $0 }
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
        continuations(after: previousWord).contains { Self.key($0) == Self.key(word) }
    }

    private static func key(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "’", with: "'")
    }
}
