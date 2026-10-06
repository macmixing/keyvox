import CoreGraphics

/// One typed word frozen for parameter search: the taps, the context, and the engine's
/// candidates.
struct TuningSample {
    let intendedWord: String
    let typedWord: String
    let touches: [CGPoint]
    let previousWords: [String]
    let candidates: [String]
}
