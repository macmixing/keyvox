import Foundation

/// Words the user keeps typing that the keyboard does not know, learned the way the system
/// keyboard learns them (measured on iOS 27 with `Tools/AppleKeyboardBaseline`): a word left as
/// typed for the second time is learned, wherever it was typed, and space leaves it alone. The
/// suggestion bar offers it, as the user first wrote it, once they wrote it twice that way, with
/// capitals or without; once the user wrote it with capitals at least twice and more often than
/// without, typing it without them gives it the capitals they first gave it; and after a word it
/// followed twice it comes first. The user can forget a learned word, and typing it
/// again starts over. Words are compared the way personal words are.
public struct LearnedWords: Sendable, Equatable {
    /// A word the user left as typed, and how they wrote it.
    public struct Use: Sendable, Equatable {
        /// How the user first wrote the word.
        public let firstForm: String
        /// How the user first wrote the word with capitals, if they ever did.
        public let capitalForm: String?
        public let lowercaseUses: Int
        public let capitalUses: Int
        /// How often the word followed each word before it, in `PersonalVocabulary.key` form,
        /// with `ContextLanguageScorer.sentenceStart` where it started a sentence.
        public let previousWords: [String: Int]
        public let lastUsed: Date

        public var count: Int { lowercaseUses + capitalUses }

        public init(
            firstForm: String,
            capitalForm: String?,
            lowercaseUses: Int,
            capitalUses: Int,
            previousWords: [String: Int],
            lastUsed: Date
        ) {
            self.firstForm = firstForm
            self.capitalForm = capitalForm
            self.lowercaseUses = lowercaseUses
            self.capitalUses = capitalUses
            self.previousWords = previousWords
            self.lastUsed = lastUsed
        }

        /// Whether the suggestion bar offers the word: once the user wrote it at least twice the
        /// way they first did, with capitals or without.
        public var isOffered: Bool {
            (firstForm == firstForm.lowercased() ? lowercaseUses : capitalUses) >= LearnedWords.usesToLearn
        }

        /// Whether a typing of the word without capitals gets `capitalForm`: once the user wrote
        /// it with capitals at least twice and more often than without.
        public var keepsCapitals: Bool {
            capitalForm != nil && capitalUses >= LearnedWords.capitalUsesToKeepCapitals && capitalUses > lowercaseUses
        }

        /// The words before it that it followed often enough to come first after them.
        public var oftenFollowed: Set<String> {
            Set(previousWords.filter { $0.value >= LearnedWords.usesToComeFirst }.keys)
        }
    }

    /// The use that makes a word learned.
    public static let usesToLearn = 2
    /// Uses with capitals after which typing the word without them gives it those capitals.
    public static let capitalUsesToKeepCapitals = 2
    /// Uses after the same word after which the word comes first there.
    public static let usesToComeFirst = 2
    /// Words tracked at most, learned or not; the ones used longest ago go first.
    public static let capacity = 2_000
    /// Words before it tracked per word at most; the least followed go first.
    public static let previousWordCapacity = 8

    public private(set) var uses: [String: Use]

    public init(uses: [String: Use] = [:]) {
        self.uses = uses
    }

    /// The learned words, by `PersonalVocabulary.key`.
    public var learned: [String: Use] {
        uses.filter { $0.value.count >= Self.usesToLearn }
    }

    public func contains(_ word: String) -> Bool {
        (uses[PersonalVocabulary.key(word)]?.count ?? 0) >= Self.usesToLearn
    }

    /// Records that the user left `form` as typed after `previousWord`, or at the start of a
    /// sentence when it is nil. Returns whether this changed a learned word: learned it, or
    /// changed how it is written or where it comes first.
    @discardableResult
    public mutating func recordUse(of form: String, after previousWord: String?, at date: Date) -> Bool {
        let key = PersonalVocabulary.key(form)
        let previous = uses[key]
        let hasCapitals = form != form.lowercased()
        var previousWords = previous?.previousWords ?? [:]
        previousWords[previousWord.map(PersonalVocabulary.key) ?? ContextLanguageScorer.sentenceStart, default: 0] += 1
        if previousWords.count > Self.previousWordCapacity,
           let least = previousWords.min(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key {
            previousWords[least] = nil
        }
        let use = Use(
            firstForm: previous?.firstForm ?? form,
            capitalForm: previous?.capitalForm ?? (hasCapitals ? form : nil),
            lowercaseUses: (previous?.lowercaseUses ?? 0) + (hasCapitals ? 0 : 1),
            capitalUses: (previous?.capitalUses ?? 0) + (hasCapitals ? 1 : 0),
            previousWords: previousWords,
            lastUsed: date
        )
        uses[key] = use
        if uses.count > Self.capacity,
           let oldest = uses.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            uses[oldest] = nil
        }
        guard use.count >= Self.usesToLearn else { return false }
        guard let previous, previous.count >= Self.usesToLearn else { return true }
        return previous.isOffered != use.isOffered || previous.keepsCapitals != use.keepsCapitals
            || previous.oftenFollowed != use.oftenFollowed
    }

    /// Forgets the learned word `word`. Returns whether it was learned.
    @discardableResult
    public mutating func forget(_ word: String) -> Bool {
        guard contains(word) else { return false }
        uses[PersonalVocabulary.key(word)] = nil
        return true
    }
}
