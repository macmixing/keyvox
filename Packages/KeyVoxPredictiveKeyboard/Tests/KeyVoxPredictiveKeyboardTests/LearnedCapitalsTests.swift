import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A dictionary word the user writes with capitals within a sentence keeps the first way they
/// wrote it, as on the system keyboard, until the user forgets it.
final class LearnedCapitalsTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testFirstCapitalsStay() {
        var capitals = LearnedCapitals()
        XCTAssertTrue(capitals.recordUse(of: "Rose", at: start))
        XCTAssertFalse(capitals.recordUse(of: "ROSE", at: start))
        XCTAssertEqual(capitals.form(of: "rose"), "Rose")
    }

    func testForgettingRemovesTheCapitals() {
        var capitals = LearnedCapitals()
        capitals.recordUse(of: "Rose", at: start)
        XCTAssertTrue(capitals.forget("Rose"))
        XCTAssertNil(capitals.form(of: "rose"))
        XCTAssertFalse(capitals.forget("Rose"))
    }

    func testWordsWrittenLongestAgoGoFirstPastCapacity() {
        var capitals = LearnedCapitals()
        for index in 0...LearnedCapitals.capacity {
            capitals.recordUse(of: "Word\(index)", at: start.addingTimeInterval(TimeInterval(index)))
        }
        XCTAssertEqual(capitals.uses.count, LearnedCapitals.capacity)
        XCTAssertNil(capitals.form(of: "word0"))
    }
}
