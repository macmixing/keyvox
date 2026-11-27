/// A spelling a swipe may have been, and how it ranks (`SwipeCandidateScoring`).
public struct SwipeCandidate: Sendable, Equatable {
    /// As the bundled lexicon or the user's own words spell it.
    public let spelling: String
    /// One of the user's own words, searched beside the bundled lexicon.
    public let isPersonal: Bool
    public let score: Double
    /// How much likelier the words before make it, as a natural log; `score` holds it times the
    /// model's context weight.
    public let contextLift: Double
}
