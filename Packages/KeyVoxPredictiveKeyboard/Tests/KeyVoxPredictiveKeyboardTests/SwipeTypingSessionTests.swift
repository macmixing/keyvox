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
        XCTAssertEqual(session.swipeEdit(word: "there", textBeforeCursor: "hello"), TextEdit(deleteCount: 0, insertText: "there"))
    }

    func testASpaceAfterASwipedWordIsPlainCorrectsNothingAndEndsTheRecord() {
        _ = session.swipeEdit(word: "helo", textBeforeCursor: "")
        session.textDidChange(textBeforeCursor: "helo")
        XCTAssertEqual(
            session.wordBoundaryEdit(separator: " ", textBeforeCursor: "helo", result: correctingResult(for: "helo", to: "hello")),
            TextEdit(deleteCount: 0, insertText: " ")
        )
        XCTAssertFalse(session.endsWithSwipedWord(textBeforeCursor: "helo"))
    }

    func testPunctuationRightAfterASwipedWordCorrectsNothing() {
        _ = session.swipeEdit(word: "helo", textBeforeCursor: "")
        session.textDidChange(textBeforeCursor: "helo")
        XCTAssertEqual(
            session.wordBoundaryEdit(separator: ".", textBeforeCursor: "helo", result: correctingResult(for: "helo", to: "hello")),
            TextEdit(deleteCount: 0, insertText: ".")
        )
    }

    /// A letter tapped after a swiped word goes in after a space, and starts a typed word that,
    /// spelled like the swiped one, leaves the text ending with that word again.
    func testTypingALetterAfterASwipedWordEndsItsRecord() {
        _ = session.swipeEdit(word: "mm", textBeforeCursor: "")
        session.textDidChange(textBeforeCursor: "mm")
        XCTAssertEqual(session.swipedWordLetterEdit(letter: "m", textBeforeCursor: "mm"), TextEdit(deleteCount: 0, insertText: " m"))
        session.recordTap(at: .zero, textBeforeCursor: "mm m")
        session.textDidChange(textBeforeCursor: "mm mm")
        XCTAssertFalse(session.endsWithSwipedWord(textBeforeCursor: "mm mm"))
        XCTAssertNil(session.swipedWordLetterEdit(letter: "m", textBeforeCursor: "mm mm"))
    }

    func testALetterAfterATypedWordOrASwipeSpacedFromTheWordThatFollowsGetsNoSpace() {
        session.textDidChange(textBeforeCursor: "If")
        XCTAssertNil(session.swipedWordLetterEdit(letter: "i", textBeforeCursor: "If"))
        _ = session.swipeEdit(word: "big", textBeforeCursor: "a ", textAfterCursor: "dog")
        session.textDidChange(textBeforeCursor: "a big ", textAfterCursor: "dog")
        XCTAssertNil(session.swipedWordLetterEdit(letter: "r", textBeforeCursor: "a big "))
    }

    func testForgettingTheSwipedWordEndsItsRecord() {
        _ = session.swipeEdit(word: "hello", textBeforeCursor: "")
        session.forgetSwipedWord()
        XCTAssertFalse(session.endsWithSwipedWord(textBeforeCursor: "hello"))
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

    func testASpaceAfterASwipedWordSpacedFromTheWordThatFollowsIsPlain() {
        XCTAssertEqual(
            session.swipeEdit(word: "big", textBeforeCursor: "a ", textAfterCursor: "dog"),
            TextEdit(deleteCount: 0, insertText: "big ")
        )
        session.textDidChange(textBeforeCursor: "a big ", textAfterCursor: "dog")
        XCTAssertTrue(session.endsWithSwipedWord(textBeforeCursor: "a big "))
        XCTAssertEqual(
            session.swipeEdit(word: "red", textBeforeCursor: "a big ", textAfterCursor: "dog"),
            TextEdit(deleteCount: 0, insertText: "red ")
        )
    }

    /// A result that autocorrects `word` to `correction`.
    private func correctingResult(for word: String, to correction: String) -> PredictionResult {
        let request = session.request(textBeforeCursor: word)
        return PredictionResult(
            request: request,
            bar: SuggestionBarComposer.compose(typedWord: request.currentWord, autocorrection: correction, rankedWords: []),
            autocorrection: correction
        )
    }
}
