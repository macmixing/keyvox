import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A swiped word goes in as a word picked from the suggestion bar would, and the bar then offers
/// the other words the swipe may have been until the text moves on.
final class SwipeTypingSessionTests: XCTestCase {
    private let session = PredictiveTypingSession(language: .english)

    func testASwipedWordIsFollowedByASpace() {
        XCTAssertEqual(session.swipeEdit(words: ["hello"], textBeforeCursor: ""), TextEdit(deleteCount: 0, insertText: "hello "))
        XCTAssertEqual(session.swipeEdit(words: ["there"], textBeforeCursor: "hello "), TextEdit(deleteCount: 0, insertText: "there "))
    }

    func testASwipeAfterAMarkAPickIsSpacedFromGetsASpaceFirst() {
        XCTAssertEqual(session.swipeEdit(words: ["then"], textBeforeCursor: "well,"), TextEdit(deleteCount: 0, insertText: " then "))
    }

    func testNoSpaceIsAddedBeforePunctuationThatFollows() {
        XCTAssertEqual(
            session.swipeEdit(words: ["word"], textBeforeCursor: "a ", textAfterCursor: "."),
            TextEdit(deleteCount: 0, insertText: "word")
        )
    }

    func testPunctuationRightAfterASwipeTakesThePlaceOfItsSpace() throws {
        _ = session.swipeEdit(words: ["hello"], textBeforeCursor: "")
        XCTAssertEqual(
            session.pickedWordSpaceEdit(character: "'", typesExactly: true, textBeforeCursor: "hello "),
            TextEdit(deleteCount: 1, insertText: "'")
        )
    }

    func testTheBarOffersTheOtherWordsAndTappingOneReplacesTheSwipedWord() throws {
        _ = session.swipeEdit(words: ["tired", "tires", "tried"], textBeforeCursor: "so ")
        let bar = try XCTUnwrap(session.swipeAlternativesBar(textBeforeCursor: "so tired "))
        XCTAssertEqual(bar.primary, SuggestionBar.Item(text: "tires", kind: .swipeAlternative))
        XCTAssertEqual(bar.leading, SuggestionBar.Item(text: "tried", kind: .swipeAlternative))
        let edit = session.choiceEdit(try XCTUnwrap(bar.primary), textBeforeCursor: "so tired ")
        XCTAssertEqual(edit, TextEdit(deleteCount: 6, insertText: "tires "))
        let after = try XCTUnwrap(session.swipeAlternativesBar(textBeforeCursor: "so tires "))
        XCTAssertEqual(after.primary?.text, "tired", "the swiped word is offered back")
    }

    func testTheAlternativesGoOnceTheTextMovesOn() {
        _ = session.swipeEdit(words: ["tired", "tires"], textBeforeCursor: "")
        session.textDidChange(textBeforeCursor: "tired a")
        XCTAssertNil(session.swipeAlternativesBar(textBeforeCursor: "tired a"))
        _ = session.swipeEdit(words: ["tired", "tires"], textBeforeCursor: "")
        session.recordTap(at: .zero, textBeforeCursor: "tired ")
        XCTAssertNil(session.swipeAlternativesBar(textBeforeCursor: "tired "))
    }
}
