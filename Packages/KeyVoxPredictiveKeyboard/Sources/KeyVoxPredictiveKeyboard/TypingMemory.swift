import Foundation

/// What the keyboard learns from the user's typing: the corrections they turned down
/// (`CorrectionRejections`), the words they keep typing (`LearnedWords`), and the capitals they
/// give dictionary words (`LearnedCapitals`).
///
/// One memory serves every typing session while the keyboard runs. Sessions record into it; the
/// host restores it with `init(saved:)`, saves `saved` whenever `onChange` reports a change, and
/// hands `learnedVocabulary` to its `PredictionComputer` when the change says what suggestions
/// use changed. Corrections undone right after they were made are kept only while the keyboard
/// runs. Use from one thread only.
public final class TypingMemory {
    /// What a host saves and restores.
    public struct Saved: Codable, Equatable, Sendable {
        public struct Rejection: Codable, Equatable, Sendable {
            let typed: String
            let correction: String
            let count: Int
            let lastRejected: Date
        }

        public struct WordUse: Codable, Equatable, Sendable {
            let firstForm: String
            let capitalForm: String?
            let lowercaseUses: Int
            let capitalUses: Int
            let previousWords: [String: Int]
            let lastUsed: Date
        }

        public struct Capital: Codable, Equatable, Sendable {
            let form: String
            let lastUsed: Date
        }

        let rejections: [Rejection]
        let wordUses: [WordUse]
        let capitals: [Capital]

        public init() {
            rejections = []
            wordUses = []
            capitals = []
        }

        init(rejections: [Rejection], wordUses: [WordUse], capitals: [Capital]) {
            self.rejections = rejections
            self.wordUses = wordUses
            self.capitals = capitals
        }
    }

    public private(set) var rejections: CorrectionRejections
    public private(set) var learnedWords: LearnedWords
    public private(set) var learnedCapitals: LearnedCapitals
    /// Called after anything worth saving changes, with whether `learnedVocabulary` changed.
    public var onChange: ((_ learnedVocabularyChanged: Bool) -> Void)?

    public init(saved: Saved = Saved()) {
        var rejections: [CorrectionRejections.Pair: CorrectionRejections.Rejection] = [:]
        for rejection in saved.rejections {
            rejections[CorrectionRejections.Pair(typed: rejection.typed, correction: rejection.correction)] =
                CorrectionRejections.Rejection(count: rejection.count, lastRejected: rejection.lastRejected)
        }
        var uses: [String: LearnedWords.Use] = [:]
        for use in saved.wordUses {
            uses[PersonalVocabulary.key(use.firstForm)] = LearnedWords.Use(
                firstForm: use.firstForm,
                capitalForm: use.capitalForm,
                lowercaseUses: use.lowercaseUses,
                capitalUses: use.capitalUses,
                previousWords: use.previousWords,
                lastUsed: use.lastUsed
            )
        }
        var capitals: [String: LearnedCapitals.Use] = [:]
        for capital in saved.capitals {
            capitals[PersonalVocabulary.key(capital.form)] = LearnedCapitals.Use(form: capital.form, lastUsed: capital.lastUsed)
        }
        self.rejections = CorrectionRejections(rejections: rejections)
        learnedWords = LearnedWords(uses: uses)
        learnedCapitals = LearnedCapitals(uses: capitals)
    }

    public var saved: Saved {
        Saved(
            rejections: rejections.rejections.map { pair, rejection in
                Saved.Rejection(
                    typed: pair.typed,
                    correction: pair.correction,
                    count: rejection.count,
                    lastRejected: rejection.lastRejected
                )
            }.sorted { ($0.typed, $0.correction) < ($1.typed, $1.correction) },
            wordUses: learnedWords.uses.values.map { use in
                Saved.WordUse(
                    firstForm: use.firstForm,
                    capitalForm: use.capitalForm,
                    lowercaseUses: use.lowercaseUses,
                    capitalUses: use.capitalUses,
                    previousWords: use.previousWords,
                    lastUsed: use.lastUsed
                )
            }.sorted { $0.firstForm < $1.firstForm },
            capitals: learnedCapitals.uses.values.map { use in
                Saved.Capital(form: use.form, lastUsed: use.lastUsed)
            }.sorted { $0.form < $1.form }
        )
    }

    /// What suggestions use of what the keyboard learned.
    public var learnedVocabulary: LearnedVocabulary {
        LearnedVocabulary(learnedWords: learnedWords, learnedCapitals: learnedCapitals)
    }

    func recordUndo(of correction: String, typed: String) {
        rejections.recordUndo(of: correction, typed: typed)
    }

    func recordRejection(of correction: String, typed: String, at date: Date) {
        rejections.recordRejection(of: correction, typed: typed, at: date)
        onChange?(false)
    }

    func recordAcceptance(of correction: String, typed: String) {
        guard rejections.remembers(correction, of: typed) else { return }
        rejections.recordAcceptance(of: correction, typed: typed)
        onChange?(false)
    }

    /// Records a use of a word the keyboard does not know, after `previousWord`, or at the start
    /// of a sentence when it is nil.
    func recordUse(of word: String, after previousWord: String?, at date: Date) {
        let changed = learnedWords.recordUse(of: word, after: previousWord, at: date)
        onChange?(changed)
    }

    /// Records a dictionary word the user wrote with capitals within a sentence.
    func recordCapitalUse(of word: String, at date: Date) {
        let changed = learnedCapitals.recordUse(of: word, at: date)
        onChange?(changed)
    }

    /// Forgets the learned word `word`, or the capitals the user gives the dictionary word `word`.
    /// Returns whether there was either.
    @discardableResult
    public func forget(_ word: String) -> Bool {
        let forgotWord = learnedWords.forget(word)
        let forgotCapitals = forgotWord == false && learnedCapitals.form(of: word) == word && learnedCapitals.forget(word)
        guard forgotWord || forgotCapitals else { return false }
        onChange?(true)
        return true
    }

    /// Forgets everything, as when the user resets what the keyboard learned.
    public func clear() {
        rejections = CorrectionRejections()
        learnedWords = LearnedWords()
        learnedCapitals = LearnedCapitals()
        onChange?(true)
    }
}
