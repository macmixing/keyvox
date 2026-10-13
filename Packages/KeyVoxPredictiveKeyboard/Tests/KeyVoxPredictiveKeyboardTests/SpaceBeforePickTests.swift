import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Tapping a suggestion right after a mark with no space, as the system keyboard does: after a
/// mark a picked word is spaced away from, the first tap adds the space and the next one picks;
/// after a mark the bar offers no next words after, there is nothing to tap; after any other
/// mark the tap picks at once.
final class SpaceBeforePickTests: XCTestCase {
    private let pick = SuggestionBar.Item(text: "we", kind: .suggestion)

    func testFirstTapAfterACommaOnlyAddsTheSpace() {
        let session = PredictiveTypingSession()
        let first = session.choiceEdit(pick, textBeforeCursor: "Hello,")
        XCTAssertEqual(first, TextEdit(deleteCount: 0, insertText: " "))
        let second = session.choiceEdit(pick, textBeforeCursor: "Hello," + first.insertText)
        XCTAssertEqual(second.insertText, pick.text + " ")
    }

    func testNoNextWordsRightAfterAHyphen() throws {
        let computer = PredictionComputer(engine: try EnglishPredictiveEngine())
        let session = PredictiveTypingSession()
        XCTAssertEqual(try computer.compute(session.request(textBeforeCursor: "Hello-")).bar, .empty)
        XCTAssertNotEqual(try computer.compute(session.request(textBeforeCursor: "Hello, ")).bar, .empty)
    }

    func testTapAfterAnOpeningBracketPicksAtOnce() {
        let edit = PredictiveTypingSession().choiceEdit(pick, textBeforeCursor: "Hello(")
        XCTAssertEqual(edit.insertText, pick.text + " ")
    }
}
