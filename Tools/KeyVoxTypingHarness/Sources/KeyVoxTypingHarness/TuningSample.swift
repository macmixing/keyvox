import CoreGraphics

/// One typed word frozen for parameter search: the taps, the context, the engine's
/// candidates, and what the July decider did with them.
struct TuningSample {
    let intendedWord: String
    let typedWord: String
    let touches: [CGPoint]
    let previousWords: [String]
    let candidates: [String]
    let julyFinalWord: String
}
