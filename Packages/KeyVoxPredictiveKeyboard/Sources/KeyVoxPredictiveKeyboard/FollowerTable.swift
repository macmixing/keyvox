import Foundation

/// A bundled list of contexts and the words that follow them, as Tools/KeyVoxLanguageModel's
/// follower builders write it: a context, a tab, and its followers as `word:log probability`,
/// likeliest first. Kept as indices into one list of the followers, mapped rather than copied.
struct FollowerTable: Sendable {
    /// Every follower, written once; the lists below refer to them by index.
    private let followers: [String]
    /// The followers' indices and log probabilities, each context's run in a row.
    private let followerIndices: [UInt16]
    private let followerScores: [Float]
    /// Each context's run of followers.
    private let contextRuns: [String: Range<Int>]

    init(contentsOf url: URL) throws {
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

    /// The followers of `context`, likeliest first, with their log probabilities.
    func followers(of context: String) -> [(word: String, logProbability: Float)] {
        (contextRuns[context] ?? 0..<0).map { (followers[Int(followerIndices[$0])], followerScores[$0]) }
    }
}
