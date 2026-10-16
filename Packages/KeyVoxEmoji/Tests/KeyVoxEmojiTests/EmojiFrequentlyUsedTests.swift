import XCTest
@testable import KeyVoxEmoji

/// The Frequently Used section ranks emoji as the system keyboard did when watched: the starters
/// first, used emoji ahead of them by how much and how lately they were used, as many as asked.
final class EmojiFrequentlyUsedTests: XCTestCase {
    private let starters = (0..<EmojiFrequentlyUsed.capacity).map { "s\($0)" }
    private let count = EmojiFrequentlyUsed.capacity

    func testTheBundledStartersFillTheSection() throws {
        let starters = try EmojiFrequentlyUsed.bundledStarters()
        XCTAssertEqual(starters.count, EmojiFrequentlyUsed.capacity)
        XCTAssertEqual(EmojiFrequentlyUsed().shown(starters: starters, count: count), starters)
    }

    func testAUsedEmojiLeadsAndPushesTheLastStarterOut() {
        var frequentlyUsed = EmojiFrequentlyUsed()
        frequentlyUsed.recordUse(of: "a")
        XCTAssertEqual(frequentlyUsed.shown(starters: starters, count: count), ["a"] + starters.dropLast())
    }

    /// As recorded: an emoji used twice, then eight others once each, ranks after the three
    /// most recent and before the rest.
    func testTwoUsesRankBetweenTheThirdAndFourthMostRecentSingleUse() {
        var frequentlyUsed = EmojiFrequentlyUsed()
        frequentlyUsed.recordUse(of: "twice")
        frequentlyUsed.recordUse(of: "twice")
        let singles = (1...8).map { "once\($0)" }
        singles.forEach { frequentlyUsed.recordUse(of: $0) }

        let shown = frequentlyUsed.shown(starters: starters, count: count)
        XCTAssertEqual(Array(shown.prefix(9)), Array(singles.suffix(3).reversed()) + ["twice"] + Array(singles.prefix(5).reversed()))
    }

    func testTheSectionNeverGrowsPastItsCapacity() {
        var frequentlyUsed = EmojiFrequentlyUsed()
        (0..<(EmojiFrequentlyUsed.capacity * 2)).forEach { frequentlyUsed.recordUse(of: "e\($0)") }
        XCTAssertEqual(frequentlyUsed.shown(starters: starters, count: count).count, EmojiFrequentlyUsed.capacity)
    }

    /// A section asked for more than the used emoji kept fills the rest with starters, in order.
    func testALargerSectionFillsPastTheKeptUsesWithStarters() {
        var frequentlyUsed = EmojiFrequentlyUsed()
        let used = (0..<(EmojiFrequentlyUsed.capacity * 2)).map { "e\($0)" }
        used.forEach { frequentlyUsed.recordUse(of: $0) }
        let shown = frequentlyUsed.shown(starters: starters, count: count + 2)
        XCTAssertEqual(shown, Array(used.suffix(count).reversed()) + starters.prefix(2))
    }

    /// A word's emoji in the suggestion bar put the one used last first, then the rest in order.
    func testOrderingPutsTheLastUsedFirst() {
        var frequentlyUsed = EmojiFrequentlyUsed()
        XCTAssertEqual(frequentlyUsed.ordering(["a", "b", "c"]), ["a", "b", "c"])
        frequentlyUsed.recordUse(of: "b")
        frequentlyUsed.recordUse(of: "c")
        XCTAssertEqual(frequentlyUsed.ordering(["a", "b", "c"]), ["c", "b", "a"])
    }
}
