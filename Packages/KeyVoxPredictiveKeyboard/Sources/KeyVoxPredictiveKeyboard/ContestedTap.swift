/// A tap that hit a non-letter key close enough to letter keys that it may have been
/// meant for one of them.
public struct ContestedTap: Sendable, Equatable {
    public enum OtherKey: Sendable, Equatable {
        /// Space or return: ends the word, so it competes with the letter on how complete
        /// the word already is.
        case wordBoundary
        /// Delete: a touch on the key itself always deletes, since a letter typed in its place
        /// adds to the text the user is taking away; only a touch in the gap beside it may be
        /// meant for a letter.
        case delete
        /// Shift, 123, or the globe: rarely meant in the middle of a word.
        case control
        /// The typing language's accent key (`AccentKey`): competes with the letter on how likely
        /// the word it would make is, as space competes on how complete the word already is.
        case accentKey
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
    /// What the other key would leave, when that is a real word or begins one: for space or
    /// return the word typed so far, for the accent key the word with what it types.
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
