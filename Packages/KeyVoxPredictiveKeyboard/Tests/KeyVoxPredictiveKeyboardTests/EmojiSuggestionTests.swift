import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Emoji in the suggestion bar, as the system keyboard was seen offering them: for the word typed
/// right before the cursor, or the last word before it when only spaces and punctuation follow it,
/// in the trailing slot; tapping one types it in place of the typed word, or after the space.
final class EmojiSuggestionTests: XCTestCase {
    func testEmojiAreForTheWordTypedOrTheLastWordBeforeSpacesAndPunctuation() {
        let session = PredictiveTypingSession()
        XCTAssertEqual(session.emojiWord(textBeforeCursor: "I love dog"), "dog")
        XCTAssertEqual(session.emojiWord(textBeforeCursor: "I love pizza "), "pizza")
        XCTAssertEqual(session.emojiWord(textBeforeCursor: "so dog. "), "dog")
        XCTAssertEqual(session.emojiWord(textBeforeCursor: "so dog,"), "dog")
        XCTAssertEqual(session.emojiWord(textBeforeCursor: "so dog and "), "and")
    }

    func testNoEmojiInsideAWordAfterAnEmojiALineBreakOrWithASelection() {
        let session = PredictiveTypingSession()
        XCTAssertNil(session.emojiWord(textBeforeCursor: "I love do", textAfterCursor: "g"))
        XCTAssertNil(session.emojiWord(textBeforeCursor: "pizza 🍕 "))
        XCTAssertNil(session.emojiWord(textBeforeCursor: "pizza\n"))
        XCTAssertNil(session.emojiWord(textBeforeCursor: "I love ", selectedText: "dog"))
        XCTAssertNil(session.emojiWord(textBeforeCursor: ""))
    }

    func testEmojiTakeTheTrailingSlot() {
        let bar = SuggestionBar(
            primary: SuggestionBar.Item(text: "dogs", kind: .suggestion),
            leading: SuggestionBar.Item(text: "dog", kind: .typed),
            trailing: SuggestionBar.Item(text: "doggy", kind: .suggestion)
        ).showing(emoji: ["🐕", "🐶"])
        XCTAssertNil(bar.trailing)
        XCTAssertEqual(bar.emoji.map(\.text), ["🐕", "🐶"])
        XCTAssertEqual(bar.emoji.map(\.kind), [.emoji, .emoji])
        XCTAssertEqual(bar.primary?.text, "dogs")
    }

    func testTappingAnEmojiReplacesTheTypedWord() {
        let edit = PredictiveTypingSession().choiceEdit(SuggestionBar.Item(text: "🐶", kind: .emoji), textBeforeCursor: "dog")
        XCTAssertEqual(edit.deleteCount, "dog".count)
        XCTAssertEqual(edit.insertText, "🐶 ")
    }

    func testTappingAnEmojiAfterTheSpaceKeepsTheWord() {
        let edit = PredictiveTypingSession().choiceEdit(SuggestionBar.Item(text: "🍕", kind: .emoji), textBeforeCursor: "pizza ")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insertText, "🍕 ")
    }

    func testTappingAnEmojiAfterACommaTypesItSpacedAwayFromTheComma() {
        let edit = PredictiveTypingSession().choiceEdit(SuggestionBar.Item(text: "🐶", kind: .emoji), textBeforeCursor: "so dog,")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insertText, " 🐶 ")
    }
}
