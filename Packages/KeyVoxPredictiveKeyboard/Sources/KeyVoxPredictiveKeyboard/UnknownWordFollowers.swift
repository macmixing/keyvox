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

    /// Every follower, written once; the lists below refer to them by index.
    private let followers: [String]
    /// The followers' indices and log probabilities, each context's run in a row.
    private let followerIndices: [UInt16]
    private let followerScores: [Float]
    /// Each context's run of followers.
    private let contextRuns: [String: Range<Int>]

    /// Reads the file, mapped rather than copied, without keeping its text.
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        var followers: [String] = []
        var indicesByFollower: [String: UInt16] = [:]
        var followerIndices: [UInt16] = []
        var followerScores: [Float] = []
        var contextRuns: [String: Range<Int>] = [:]
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            for line in ScoredWordLines.lines(in: bytes) {
                guard let tab = bytes[line].firstIndex(of: UInt8(ascii: "\t")) else { continue }
                let context = String(decoding: bytes[line.lowerBound..<tab], as: UTF8.self)
                let start = followerIndices.count
                for pair in ScoredWordLines.pairs(in: bytes, (tab + 1)..<line.upperBound) {
                    let index = indicesByFollower[pair.word] ?? {
                        let index = UInt16(followers.count)
                        followers.append(pair.word)
                        indicesByFollower[pair.word] = index
                        return index
                    }()
                    followerIndices.append(index)
                    followerScores.append(pair.value)
                }
                contextRuns[context] = start..<followerIndices.count
            }
        }
        self.followers = followers
        self.followerIndices = followerIndices
        self.followerScores = followerScores
        self.contextRuns = contextRuns
    }

    /// The likeliest words right after an unknown word, likeliest first.
    /// - Parameter wordBefore: The word before the unknown word, or nil where the unknown word
    ///   starts a sentence.
    public func words(afterUnknownWordFollowing wordBefore: String?) -> [String] {
        let context = wordBefore?.lowercased() ?? ContextLanguageScorer.sentenceStart
        var scores: [UInt16: Float] = [:]
        for index in contextRuns[context] ?? 0..<0 {
            scores[followerIndices[index]] = followerScores[index]
        }
        for index in contextRuns[Self.anyContext] ?? 0..<0 {
            let backedOff = followerScores[index] + Self.backoffLogFactor
            scores[followerIndices[index]] = max(scores[followerIndices[index]] ?? -.infinity, backedOff)
        }
        return scores.sorted { left, right in
            left.value != right.value ? left.value > right.value : followers[Int(left.key)] < followers[Int(right.key)]
        }.map { followers[Int($0.key)] }
    }
}
