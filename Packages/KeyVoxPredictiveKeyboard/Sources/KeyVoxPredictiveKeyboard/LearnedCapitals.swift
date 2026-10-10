import Foundation

/// Dictionary words the user writes with capitals within a sentence, as a name such as "Rose",
/// learned the way the system keyboard learns them (measured on iOS 27 with
/// `Tools/AppleKeyboardBaseline`): from the first such use, suggestions for the word show it the
/// user's way, and the first way stays when the user writes it differently later. A capital
/// that only starts a sentence teaches nothing, and the words the user types are never changed.
/// The user can forget a word's capitals. Words are compared the way personal words are.
public struct LearnedCapitals: Sendable, Equatable {
    /// How the user writes a word, and when they last did.
    public struct Use: Sendable, Equatable {
        public let form: String
        public let lastUsed: Date

        public init(form: String, lastUsed: Date) {
            self.form = form
            self.lastUsed = lastUsed
        }
    }

    /// Words kept at most; the ones written longest ago go first.
    public static let capacity = 2_000

    public private(set) var uses: [String: Use]

    public init(uses: [String: Use] = [:]) {
        self.uses = uses
    }

    /// How the user writes `word`, if they wrote it with capitals within a sentence.
    public func form(of word: String) -> String? {
        uses[PersonalVocabulary.key(word)]?.form
    }

    /// Records that the user wrote the dictionary word `form` with capitals within a sentence.
    /// Returns whether its form is new.
    @discardableResult
    public mutating func recordUse(of form: String, at date: Date) -> Bool {
        let key = PersonalVocabulary.key(form)
        let existing = uses[key]
        uses[key] = Use(form: existing?.form ?? form, lastUsed: date)
        if uses.count > Self.capacity,
           let oldest = uses.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            uses[oldest] = nil
        }
        return existing == nil
    }

    /// Forgets how the user writes `word`. Returns whether it was learned.
    @discardableResult
    public mutating func forget(_ word: String) -> Bool {
        uses.removeValue(forKey: PersonalVocabulary.key(word)) != nil
    }
}
