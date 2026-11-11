import CoreGraphics
import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A word the user types right before another word is suggested for on its own, as on the system
/// keyboard: a pick replaces only the typed letters and keeps the word after them. A word the
/// cursor was moved into is still suggested for as a whole.
final class TypedWordBeforeWordTests: XCTestCase {
    private let textBefore = "I am "
    private let textAfter = "to you now"
    private let typed = "typin"
    private let pick = SuggestionBar.Item(text: "typing", kind: .suggestion)

    func testWordTypedRightBeforeAnotherIsSuggestedForAlone() {
        let session = PredictiveTypingSession()
        type(typed, after: textBefore, before: textAfter, in: session)

        let request = session.request(textBeforeCursor: textBefore + typed, textAfterCursor: textAfter)
        XCTAssertEqual(request.currentWord, typed)
        XCTAssertEqual(request.touches.count, typed.count)
        XCTAssertFalse(request.keepsTypedWord)

        let edit = session.choiceEdit(pick, textBeforeCursor: textBefore + typed, textAfterCursor: textAfter)
        XCTAssertEqual(edit, TextEdit(deleteCount: typed.count, insertText: pick.text + " "))
    }

    func testDeletingALetterThatMatchesTheNextWordKeepsTheTypedWordAlone() {
        let session = PredictiveTypingSession()
        let extra = String(textAfter.prefix(1))
        type(typed + extra, after: textBefore, before: textAfter, in: session)
        session.textDidChange(textBeforeCursor: textBefore + typed, textAfterCursor: textAfter)

        let request = session.request(textBeforeCursor: textBefore + typed, textAfterCursor: textAfter)
        XCTAssertEqual(request.currentWord, typed)
        XCTAssertEqual(request.touches.count, typed.count)

        let edit = session.choiceEdit(pick, textBeforeCursor: textBefore + typed, textAfterCursor: textAfter)
        XCTAssertEqual(edit, TextEdit(deleteCount: typed.count, insertText: pick.text + " "))
    }

    func testCursorMovedIntoAWordJustTypedSuggestsForTheWholeWord() {
        let session = PredictiveTypingSession()
        let word = typed + textAfter.prefix { $0.isLetter }
        type(word, after: textBefore, before: "", in: session)
        let rest = String(word.dropFirst(typed.count))
        session.textDidChange(textBeforeCursor: textBefore + typed, textAfterCursor: rest)

        let request = session.request(textBeforeCursor: textBefore + typed, textAfterCursor: rest)
        XCTAssertEqual(request.currentWord, word)
        XCTAssertTrue(request.keepsTypedWord)
    }

    /// Types `word` one tapped letter at a time between `before` and `after`, as the keyboard
    /// reports each tap and the text change after it.
    private func type(_ word: String, after before: String, before after: String, in session: PredictiveTypingSession) {
        for count in 1...word.count {
            let text = before + word.prefix(count)
            session.recordTap(at: CGPoint(x: count, y: 0), textBeforeCursor: text)
            session.textDidChange(textBeforeCursor: text, textAfterCursor: after)
        }
    }
}
