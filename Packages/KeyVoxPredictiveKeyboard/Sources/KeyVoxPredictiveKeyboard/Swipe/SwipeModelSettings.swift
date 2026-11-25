import Foundation

/// A typing language's `swipe.json`: which keys the bundled swipe model scores, in the order
/// it scores them, and the settings its candidates are searched and ranked with.
public struct SwipeModelSettings: Decodable, Sendable, Equatable {
    /// How the beam search keeps its prefixes (`SwipeBeamSearch`).
    public struct Pruning: Decodable, Sendable, Equatable {
        /// How many key-path prefixes survive each frame.
        public let beam: Int
        /// How strongly a prefix's log-probability is divided by its length when pruning.
        public let gamma: Double
        /// How much each key of a prefix adds to its pruning score.
        public let beta: Double
    }

    /// How a candidate word is ranked (`SwipeCandidateScoring`).
    public struct Scoring: Decodable, Sendable, Equatable {
        /// How strongly the swipe's log-probability of the word is divided by its key-path length.
        public let gamma: Double
        /// The weight of the word's dictionary probability (0 to 255, already log-scaled).
        public let frequencyWeight: Double
        /// What each key of the word's key path adds.
        public let lengthBonus: Double
        /// The weight of how much likelier the words before make the word than it is on its own,
        /// as a natural log.
        public let contextWeight: Double
        /// The weight of that among words whose key paths are the same, which the swipe cannot
        /// tell apart (`SwipeWordDecoder`).
        public let samePathContextWeight: Double
        /// How many of the best words, by everything but context, are weighed in context.
        public let contextCandidates: Int
        /// The dictionary probability the user's own words, which the dictionary lacks, are
        /// ranked with: that of the dictionary's words seen about as often as typing takes the
        /// user's words to be (`ContextLanguageScorer`).
        public let personalWordFrequency: Double
    }

    /// The model's keys, in the order its emissions list them after the blank.
    public let letters: String
    /// Whether a letter repeated right after itself is a key of its own in key paths.
    public let keepsDoubleLetters: Bool
    public let pruning: Pruning
    public let scoring: Scoring

    /// The settings of `language`'s bundled swipe model.
    public static func bundled(for language: TypingLanguage) throws -> SwipeModelSettings {
        try SwipeModelSettings(contentsOf: language.resources.url("swipe.json"))
    }

    public init(contentsOf url: URL) throws {
        do {
            self = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        } catch {
            throw PredictiveKeyboardError.invalidSwipeModel(url.lastPathComponent)
        }
    }

    /// Each model key's letter with its index in the model's emissions, the blank aside.
    var keyIndex: [Unicode.Scalar: Int] {
        Dictionary(uniqueKeysWithValues: letters.unicodeScalars.enumerated().map { ($1, $0) })
    }
}
