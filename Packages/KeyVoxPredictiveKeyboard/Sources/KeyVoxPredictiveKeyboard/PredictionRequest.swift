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
    /// The user undid an autocorrection of this exact word, so space must keep it.
    public let keepsTypedWord: Bool
    public let isAtSentenceStart: Bool
}
