import Foundation

/// The emoji the Frequently Used section shows, ranked as the system emoji keyboard ranks them,
/// as recorded by watching it (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`):
/// each use adds one to the emoji's score and every later use of an emoji scales every score
/// down, so an emoji used twice ranks above one used once three uses ago but below one used
/// once two uses ago. The section holds as many emoji as its page asks for; the emoji the keyboard
/// starts with fill what used emoji leave, in their order.
public struct EmojiFrequentlyUsed: Codable, Equatable, Sendable {
    /// The used emoji kept, and the fewest the section shows: as many as it showed when measured.
    public static let capacity = 30
    /// What each later use scales an earlier use's weight by: in three recordings an emoji used
    /// twice landed between the emoji used once two and three uses after it, which holds for
    /// factors between 0.882 and 0.898.
    public static let decay = 0.89

    private struct Use: Codable, Equatable, Sendable {
        let emoji: String
        var score: Double
    }

    private var uses: [Use] = []

    public init() {}

    /// The emoji the system keyboard's Frequently Used section starts with, in order, written by
    /// `Tools/KeyVoxEmojiData/write_emoji_catalog.py`.
    public static func bundledStarters() throws -> [String] {
        let url = try EmojiDataLocator().url(name: "emoji_starters", extension: "txt")
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    /// Counts a use of `emoji`.
    public mutating func recordUse(of emoji: String) {
        for index in uses.indices {
            uses[index].score *= Self.decay
        }
        if let index = uses.firstIndex(where: { $0.emoji == emoji }) {
            uses[index].score += 1
        } else {
            uses.append(Use(emoji: emoji, score: 1))
        }
        // Every use lands on its own scale, so no two emoji share a score.
        uses.sort { $0.score > $1.score }
        if uses.count > Self.capacity {
            uses.removeLast(uses.count - Self.capacity)
        }
    }

    /// `emoji` with the used ones first, best first, then the rest in their order, as the system
    /// keyboard's suggestion bar was seen putting a word's emoji the user last picked first.
    public func ordering(_ emoji: [String]) -> [String] {
        let scores = Dictionary(uses.map { ($0.emoji, $0.score) }, uniquingKeysWith: max)
        let used = emoji.filter { scores[$0] != nil }.sorted { scores[$0, default: 0] > scores[$1, default: 0] }
        return used + emoji.filter { scores[$0] == nil }
    }

    /// What a section of `count` emoji shows: the used emoji, best first, then `starters` the used
    /// emoji leave room for, in order.
    public func shown(starters: [String], count: Int) -> [String] {
        let used = Array(uses.map(\.emoji).prefix(count))
        let usedSet = Set(used)
        return used + starters.lazy.filter { usedSet.contains($0) == false }.prefix(count - used.count)
    }
}
