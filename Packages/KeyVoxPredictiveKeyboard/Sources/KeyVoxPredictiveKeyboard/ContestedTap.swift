/// A tap that hit a non-letter key close enough to letter keys that it may have been
/// meant for one of them.
public struct ContestedTap: Sendable, Equatable {
    public enum OtherKey: Sendable, Equatable {
        /// Space or return: ends the word, so it competes with the letter on how complete
        /// the word already is.
        case wordBoundary
        /// Shift, delete, 123, or the globe: rarely meant in the middle of a word.
        case control
    }

    /// A letter key near the touch and the likeliest real word it would lead to.
    public struct Letter: Sendable, Equatable {
        public let letter: Character
        /// How far the touch is outside this letter key, in key pitches.
        public let distance: Double
        public let continuationLogProbability: Double

        public init(letter: Character, distance: Double, continuationLogProbability: Double) {
            self.letter = letter
            self.distance = distance
            self.continuationLogProbability = continuationLogProbability
        }
    }

    public let otherKey: OtherKey
    /// Whether the touch is on the other key itself rather than in the gap beside it.
    public let landedOnOtherKey: Bool
    /// Whether the tap came before any letter of the current word.
    public let startsWord: Bool
    /// Nearby letters that lead to a real word.
    public let letters: [Letter]
    /// The word typed so far, if it is a real word.
    public let endingLogProbability: Double?

    public init(
        otherKey: OtherKey,
        landedOnOtherKey: Bool,
        startsWord: Bool,
        letters: [Letter],
        endingLogProbability: Double?
    ) {
        self.otherKey = otherKey
        self.landedOnOtherKey = landedOnOtherKey
        self.startsWord = startsWord
        self.letters = letters
        self.endingLogProbability = endingLogProbability
    }
}
