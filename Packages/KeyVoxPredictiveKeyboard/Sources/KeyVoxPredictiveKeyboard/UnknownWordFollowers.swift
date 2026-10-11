import Foundation

/// The words the suggestion bar offers right after a word the bundled data has nothing to follow,
/// such as a name, a brand, or a word the keyboard learned from the user's typing: what follows
/// such a word after the word before it, as the system keyboard offers "to" in "We need ___".
/// The list is written by Tools/KeyVoxLanguageModel/write_unknown_word_followers.py, which
/// documents the file's lines.
public struct UnknownWordFollowers: Sendable {
    private static let anyContext = "*"
    /// How much less likely a follower of any word counts than a follower of the word before:
    /// the backoff `ContextLanguageScorer` applies to a shorter context.
    private static let backoffLogFactor = Float(log(0.4))

    private let table: FollowerTable

    public init(contentsOf url: URL) throws {
        table = try FollowerTable(contentsOf: url)
    }

    /// The likeliest words right after an unknown word, likeliest first.
    /// - Parameter wordBefore: The word before the unknown word, or nil where the unknown word
    ///   starts a sentence.
    public func words(afterUnknownWordFollowing wordBefore: String?) -> [String] {
        let context = wordBefore?.lowercased() ?? ContextLanguageScorer.sentenceStart
        var scores: [String: Float] = [:]
        for follower in table.followers(of: context) {
            scores[follower.word] = follower.logProbability
        }
        for follower in table.followers(of: Self.anyContext) {
            scores[follower.word] = max(scores[follower.word] ?? -.infinity, follower.logProbability + Self.backoffLogFactor)
        }
        return scores.sorted { left, right in
            left.value != right.value ? left.value > right.value : left.key < right.key
        }.map(\.key)
    }
}
