/// What the keyboard learned from the user's typing, as suggestions use it: the learned words
/// (`LearnedWords`) and the capitals the user gives dictionary words (`LearnedCapitals`).
///
/// Learned words are offered after the keyboard's own words that fit the typed letters, or first
/// after a word they often follow, where space then leaves the typed letters alone; they are never
/// what space corrects a word to or completes a word into: the system keyboard offers them but
/// leaves the typing to the user.
public struct LearnedVocabulary: Sendable, Equatable {
    /// A learned word as suggestions use it.
    public struct Word: Sendable, Equatable {
        /// Whether the suggestion bar offers it.
        public let isOffered: Bool
        /// How the suggestion bar shows it.
        public let suggestedForm: String
        /// The capitals the user first gave it, if any.
        public let capitalForm: String?
        /// Whether a typing of it without capitals gets `capitalForm`.
        public let keepsCapitals: Bool
        /// The words before it, in `PersonalVocabulary.key` form, after which it comes first.
        public let oftenFollowed: Set<String>

        /// How `typed`, a typing of this word, is written: without capitals, with the user's
        /// capitals once they keep them; with only a first capital, in all capitals when the user
        /// first wrote it that way, as the system keyboard does; otherwise as typed.
        public func written(ofTyped typed: String) -> String {
            guard let capitalForm else { return typed }
            if typed == typed.lowercased() {
                return keepsCapitals ? capitalForm : typed
            }
            let startsWithCapitalOnly = typed.first?.isUppercase == true && typed.dropFirst() == typed.dropFirst().lowercased()
            let isAllCapitals = capitalForm == capitalForm.uppercased()
            return startsWithCapitalOnly && isAllCapitals ? capitalForm : typed
        }
    }

    public static let empty = LearnedVocabulary(learnedWords: LearnedWords(), learnedCapitals: LearnedCapitals())

    private let words: [String: Word]
    private let capitals: [String: String]

    public init(learnedWords: LearnedWords, learnedCapitals: LearnedCapitals) {
        words = learnedWords.learned.mapValues { use in
            Word(
                isOffered: use.isOffered,
                suggestedForm: use.firstForm,
                capitalForm: use.capitalForm,
                keepsCapitals: use.keepsCapitals,
                oftenFollowed: use.oftenFollowed
            )
        }
        capitals = learnedCapitals.uses.mapValues(\.form)
    }

    /// The learned words, in `PersonalVocabulary.key` form.
    public var keys: [String] {
        words.keys.sorted()
    }

    /// The learned word `word`, if it is one.
    public func word(_ word: String) -> Word? {
        words[PersonalVocabulary.key(word)]
    }

    /// How the user writes the dictionary word `word` within a sentence, if with capitals.
    public func capitalForm(of word: String) -> String? {
        capitals[PersonalVocabulary.key(word)]
    }
}
