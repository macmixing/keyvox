/// One sentence of a typing language's regression check: what it says, the letters a finger
/// taps for it with where each tap lands, and the moments its suggestion bar is recorded.
public struct TypingRegressionCase: Codable, Equatable, Sendable {
    /// The sentence's words, lowercased, as it writes them.
    public let intended: [String]
    /// The letters tapped for each word: its letters, with a letter no key types tapped as the
    /// plain letter on a key, and apostrophes, which are never tapped, kept as written.
    public let words: [String]
    /// Per word, per tapped letter: `[dx, dy]` from the key's center, in key pitches.
    public let taps: [[[Double]]]
    /// When the suggestion bar is recorded.
    public let bars: [SessionTyper.BarPoint]

    public init(intended: [String], words: [String], taps: [[[Double]]], bars: [SessionTyper.BarPoint]) {
        self.intended = intended
        self.words = words
        self.taps = taps
        self.bars = bars
    }
}
