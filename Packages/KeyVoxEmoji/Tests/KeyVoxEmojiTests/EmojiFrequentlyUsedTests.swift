import XCTest
@testable import KeyVoxEmoji

/// The Frequently Used section ranks emoji as the system keyboard did when watched: the starters
/// first, used emoji ahead of them by how much and how lately they were used, at a fixed size.
final class EmojiFrequentlyUsedTests: XCTestCase {
    private let starters = (0..<EmojiFrequentlyUsed.capacity).map { "s\($0)" }

    func testTheBundledStartersFillTheSection() throws {
        let starters = try EmojiFrequentlyUsed.bundledStarters()
        XCTAssertEqual(starters.count, EmojiFrequentlyUsed.capacity)
        XCTAssertEqual(EmojiFrequentlyUsed().shown(starters: starters), starters)
    }

    func testAUsedEmojiLeadsAndPushesTheLastStarterOut() {
        var frequentlyUsed = EmojiFrequentlyUsed()
        frequentlyUsed.recordUse(of: "a")
        XCTAssertEqual(frequentlyUsed.shown(starters: starters), ["a"] + starters.dropLast())
    }

    /// As recorded: an emoji used twice, then eight others once each, ranks after the three
    /// most recent and before the rest.
    func testTwoUsesRankBetweenTheThirdAndFourthMostRecentSingleUse() {
        var frequentlyUsed = EmojiFrequentlyUsed()
        frequentlyUsed.recordUse(of: "twice")
        frequentlyUsed.recordUse(of: "twice")
        let singles = (1...8).map { "once\($0)" }
        singles.forEach { frequentlyUsed.recordUse(of: $0) }

        let shown = frequentlyUsed.shown(starters: starters)
        XCTAssertEqual(Array(shown.prefix(9)), Array(singles.suffix(3).reversed()) + ["twice"] + Array(singles.prefix(5).reversed()))
    }

    func testTheSectionNeverGrowsPastItsCapacity() {
        var frequentlyUsed = EmojiFrequentlyUsed()
        (0..<(EmojiFrequentlyUsed.capacity * 2)).forEach { frequentlyUsed.recordUse(of: "e\($0)") }
        XCTAssertEqual(frequentlyUsed.shown(starters: starters).count, EmojiFrequentlyUsed.capacity)
    }
}
