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
    /// Between words, the words the user picked from the suggestion bar in a row right before
    /// the cursor, newest first, which the next-word bar does not lead with again
    /// (`RepeatedPicks`).
    public var pickedWords: [String] = []
    /// A number drawn when the user started picking the bar's words in a row, which varies the
    /// order of about equally likely next words from one run of picks to the next (`PickVariety`).
    public var pickRun = 0
    /// Between words, whether the bar offers next words: not right after a mark the system
    /// keyboard offers none after, such as a hyphen or a slash.
    public var offersNextWords = true
    /// Right after the user deleted the separator that ended an autocorrection, what was typed
    /// before it, which the bar offers in place of suggestions.
    public var revertibleText: String?
}
