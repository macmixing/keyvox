import CoreGraphics

/// One typed word frozen for parameter search: the taps, the context on both sides, and
/// the engine's candidates.
struct TuningSample {
    let intendedWord: String
    let typedWord: String
    let touches: [CGPoint]
    let previousWords: [String]
    let followingWord: String?
    let candidates: [String]
}
