import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A swiped word goes in with no space after it, and the next swiped word goes in after a space,
/// as on the system keyboard (`~/KeyVoxLanguageData/swipe/apple-swipe-spacing/`).
final class SwipeTypingSessionTests: XCTestCase {
    private let session = PredictiveTypingSession(language: .english)

    func testASwipedWordHasNoSpaceAfterIt() {
        XCTAssertEqual(session.swipeEdit(word: "hello", textBeforeCursor: ""), TextEdit(deleteCount: 0, insertText: "hello"))
    }

    func testASwipeRightAfterASwipedWordGetsASpaceFirst() {
        _ = session.swipeEdit(word: "hello", textBeforeCursor: "")
        session.textDidChange(textBeforeCursor: "hello")
        XCTAssertTrue(session.endsWithSwipedWord(textBeforeCursor: "hello"))
        XCTAssertEqual(session.previousWords(beforeSwipeAfter: "hello"), ["hello"])
        XCTAssertEqual(session.swipeEdit(word: "there", textBeforeCursor: "hello"), TextEdit(deleteCount: 0, insertText: " there"))
    }

    func testASwipeGetsNoSpaceAtTheStartOfTheTextOrAfterASpace() {
        XCTAssertEqual(session.swipeEdit(word: "hello", textBeforeCursor: nil), TextEdit(deleteCount: 0, insertText: "hello"))
        XCTAssertEqual(session.swipeEdit(word: "there", textBeforeCursor: "hello "), TextEdit(deleteCount: 0, insertText: "there"))
    }

    func testASwipeAfterATypedWordGetsNoSpaceOfItsOwn() {
        session.textDidChange(textBeforeCursor: "hello")
        XCTAssertFalse(session.endsWithSwipedWord(textBeforeCursor: "hello"))
        XCTAssertEqual(session.swipeEdit(word: "there", textBeforeCursor: "hello"), TextEdit(deleteCount: 0, insertText: "there"))
    }

    func testASpaceAfterASwipedWordIsPlainAndCorrectsNothing() {
        _ = session.swipeEdit(word: "helo", textBeforeCursor: "")
        session.textDidChange(textBeforeCursor: "helo")
        let request = session.request(textBeforeCursor: "helo")
        let result = PredictionResult(
            request: request,
            bar: SuggestionBarComposer.compose(typedWord: request.currentWord, autocorrection: "hello", rankedWords: []),
            autocorrection: "hello"
        )
        XCTAssertEqual(
            session.wordBoundaryEdit(separator: " ", textBeforeCursor: "helo", result: result),
            TextEdit(deleteCount: 0, insertText: " ")
        )
        XCTAssertFalse(session.endsWithSwipedWord(textBeforeCursor: "helo "))
    }

    func testTypingALetterAfterASwipedWordEndsItsRecord() {
        _ = session.swipeEdit(word: "hello", textBeforeCursor: "")
        session.textDidChange(textBeforeCursor: "hellos")
        session.recordTap(at: .zero, textBeforeCursor: "hellos")
        XCTAssertFalse(session.endsWithSwipedWord(textBeforeCursor: "hellos"))
    }

    func testASwipeAfterAMarkAPickIsSpacedFromGetsASpaceFirst() {
        XCTAssertEqual(session.swipeEdit(word: "then", textBeforeCursor: "well,"), TextEdit(deleteCount: 0, insertText: " then"))
    }

    func testNoSpaceIsAddedBeforePunctuationThatFollows() {
        XCTAssertEqual(
            session.swipeEdit(word: "word", textBeforeCursor: "a ", textAfterCursor: "."),
            TextEdit(deleteCount: 0, insertText: "word")
        )
    }

    func testAWordThatFollowsTheCursorIsSpacedFromTheSwipedWord() {
        XCTAssertEqual(
            session.swipeEdit(word: "big", textBeforeCursor: "a ", textAfterCursor: "dog"),
            TextEdit(deleteCount: 0, insertText: "big ")
        )
        XCTAssertFalse(session.endsWithSwipedWord(textBeforeCursor: "a big "))
    }

    func testPunctuationRightAfterASwipedWordFollowsIt() {
        _ = session.swipeEdit(word: "hello", textBeforeCursor: "")
        XCTAssertNil(session.pickedWordSpaceEdit(character: "'", typesExactly: true, textBeforeCursor: "hello"))
    }
}
