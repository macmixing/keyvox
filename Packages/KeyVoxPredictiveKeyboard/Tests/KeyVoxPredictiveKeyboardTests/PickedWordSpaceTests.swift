import XCTest
@testable import KeyVoxPredictiveKeyboard

/// What typing a character right after a word picked from the suggestion bar does with the space
/// the pick added, as the system keyboard does.
final class PickedWordSpaceTests: XCTestCase {
    func testWordEndingCharacterTakesTheSpaceWhenListed() {
        let (session, text) = pickedWord()
        XCTAssertEqual(session.wordBoundaryEdit(separator: ".", textBeforeCursor: text, result: nil).deleteCount, 1)
    }

    func testWordEndingCharacterFollowsTheSpaceWhenNotListed() {
        let (session, text) = pickedWord()
        XCTAssertEqual(session.wordBoundaryEdit(separator: "+", textBeforeCursor: text, result: nil).deleteCount, 0)
    }

    func testApostropheTakesTheSpaceAsAClosingMark() {
        let (session, text) = pickedWord()
        let edit = session.pickedWordSpaceEdit(character: SmartQuotes.apostrophe, typesExactly: false, textBeforeCursor: text)
        XCTAssertEqual(edit?.deleteCount, 1)
        XCTAssertEqual(edit?.insertText, SmartQuotes.text(for: SmartQuotes.apostrophe, after: String(text.dropLast())))
    }

    func testLetterFollowsTheSpace() {
        let (session, text) = pickedWord()
        XCTAssertNil(session.pickedWordSpaceEdit(character: "a", typesExactly: false, textBeforeCursor: text))
    }

    /// A session right after picking a word from the bar, and the text it left.
    private func pickedWord() -> (PredictiveTypingSession, String) {
        let session = PredictiveTypingSession()
        let typed = "hel"
        let edit = session.choiceEdit(SuggestionBar.Item(text: "hello", kind: .suggestion), textBeforeCursor: typed)
        return (session, String(typed.dropLast(edit.deleteCount)) + edit.insertText)
    }
}
