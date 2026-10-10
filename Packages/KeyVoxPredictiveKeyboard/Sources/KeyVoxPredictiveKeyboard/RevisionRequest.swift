#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

/// A word the user finished as typed, together with the word they typed after it, so the
/// earlier word can be reconsidered with context from both sides ("I male mistakes").
public struct RevisionRequest: Sendable, Equatable {
    /// The earlier word as it stands in the text.
    public let word: String
    /// One touch per letter of `word`, or empty when they are unknown.
    public let touches: [CGPoint]
    /// Words before `word` in the sentence, newest first.
    public let previousWords: [String]
    /// The word typed after `word`, as it will be inserted.
    public let followingWord: String
    /// Corrections of `word` the user turned down, which a revision must not make, in the form
    /// personal words are compared in.
    public let heldBackCorrections: Set<String>

    public init(
        word: String,
        touches: [CGPoint],
        previousWords: [String],
        followingWord: String,
        heldBackCorrections: Set<String> = []
    ) {
        self.word = word
        self.touches = touches
        self.previousWords = previousWords
        self.followingWord = followingWord
        self.heldBackCorrections = heldBackCorrections
    }
}
