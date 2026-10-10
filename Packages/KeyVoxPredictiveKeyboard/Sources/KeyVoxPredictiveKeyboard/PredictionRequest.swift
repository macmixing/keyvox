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
    /// Space must keep this word as typed: the word is selected or has the cursor inside it.
    public let keepsTypedWord: Bool
    public let isAtSentenceStart: Bool
    /// How the sentence before this one ended, at a sentence start that follows one.
    public let previousSentence: SentenceEnding?
    /// Corrections of this word the user turned down, which space must not make, in the form
    /// personal words are compared in.
    public var heldBackCorrections: Set<String> = []
}
