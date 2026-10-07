#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

/// Everything needed to compute suggestions for one moment of typing, captured on the
/// host's main thread so the work can run elsewhere.
public struct PredictionRequest: Sendable, Equatable {
    public let currentWord: String
    public let touches: [CGPoint]
    public let previousWords: [String]
    /// Space must keep this word as typed: the user undid its autocorrection, or the word is
    /// selected or has the cursor inside it.
    public let keepsTypedWord: Bool
    public let isAtSentenceStart: Bool
}
