/// Words and shortcuts that belong to this user: their KeyVox Dictionary, contact names,
/// and text replacements. Personal words are never autocorrected away, are offered when
/// typed closely, and text replacement shortcuts expand at the end of a word.
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
    /// Lowercased shortcut to its expansion.
    private let expansionsByShortcut: [String: String]

    /// - Parameters:
    ///   - words: Personal words or phrases; each word of a phrase counts on its own.
    ///   - textReplacements: Shortcuts and what they expand to.
    public init(words: [String], textReplacements: [TextReplacement]) {
        var displayForms: [String: String] = [:]
        for phrase in words {
            for word in phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            where word.contains(where: \.isLetter) {
                displayForms[Self.key(word)] = displayForms[Self.key(word)] ?? word
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
        expansionsByShortcut = expansions
    }

    public var isEmpty: Bool {
        displayFormsByKey.isEmpty && expansionsByShortcut.isEmpty
    }

    public func contains(_ word: String) -> Bool {
        displayFormsByKey[Self.key(word)] != nil
    }

    /// How the user writes `word`, if it is one of theirs.
    public func displayForm(of word: String) -> String? {
        displayFormsByKey[Self.key(word)]
    }

    public func expansion(for typedWord: String) -> String? {
        expansionsByShortcut[Self.key(typedWord)]
    }

    /// Personal words within one edit of `typedWord` (two for words of eight letters or
    /// more), or that continue it, in the form the user writes them.
    public func candidates(near typedWord: String) -> [String] {
        let typed = Self.key(typedWord)
        guard typed.count >= 2 else { return [] }
        let limit = typed.count >= 8 ? 2 : 1
        return displayFormsByKey.compactMap { key, display in
            guard key != typed else { return nil }
            if key.hasPrefix(typed) { return display }
            return WordEditDistance.distance(typed, key, limit: limit) <= limit ? display : nil
        }
    }

    private static func key(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "’", with: "'")
    }
}
