import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A swiped word goes in as a word picked from the suggestion bar would.
final class SwipeTypingSessionTests: XCTestCase {
    private let session = PredictiveTypingSession(language: .english)

    func testASwipedWordIsFollowedByASpace() {
        XCTAssertEqual(session.swipeEdit(word: "hello", textBeforeCursor: ""), TextEdit(deleteCount: 0, insertText: "hello "))
        XCTAssertEqual(session.swipeEdit(word: "there", textBeforeCursor: "hello "), TextEdit(deleteCount: 0, insertText: "there "))
    }

    func testASwipeAfterAMarkAPickIsSpacedFromGetsASpaceFirst() {
        XCTAssertEqual(session.swipeEdit(word: "then", textBeforeCursor: "well,"), TextEdit(deleteCount: 0, insertText: " then "))
    }

    func testNoSpaceIsAddedBeforePunctuationThatFollows() {
        XCTAssertEqual(
            session.swipeEdit(word: "word", textBeforeCursor: "a ", textAfterCursor: "."),
            TextEdit(deleteCount: 0, insertText: "word")
        )
    }

    func testPunctuationRightAfterASwipeTakesThePlaceOfItsSpace() {
        _ = session.swipeEdit(word: "hello", textBeforeCursor: "")
        XCTAssertEqual(
            session.pickedWordSpaceEdit(character: "'", typesExactly: true, textBeforeCursor: "hello "),
            TextEdit(deleteCount: 1, insertText: "'")
        )
    }
}
