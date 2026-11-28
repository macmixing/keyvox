import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Spacing and next words around punctuation in both Spanish typing languages, as Apple's Spanish
/// (Spain) and Spanish (Latin America) keyboards were measured doing on iOS 27.2: a word picked from
/// the suggestion bar keeps its space before an apostrophe, and the bar offers no next words right
/// after a colon.
final class SpanishPunctuationSpacingTests: XCTestCase {
    private let languages: [TypingLanguage] = {
        do {
            return [.spanish, try TypingLanguage.bundled(identifier: "es-419")]
        } catch {
            fatalError("the bundled Latin American Spanish typing language did not load: \(error)")
        }
    }()

    func testAPickedWordKeepsItsSpaceBeforeAnApostrophe() {
        for language in languages {
            let (session, text) = pickedWord(in: language)
            XCTAssertNil(
                session.pickedWordSpaceEdit(character: SmartQuotes.apostrophe, typesExactly: false, textBeforeCursor: text),
                language.identifier
            )
        }
    }

    func testThePickedWordsSpaceStillGivesWayToAPeriod() {
        for language in languages {
            let (session, text) = pickedWord(in: language)
            XCTAssertEqual(session.wordBoundaryEdit(separator: ".", textBeforeCursor: text, result: nil).deleteCount, 1, language.identifier)
        }
    }

    func testNoNextWordsRightAfterAColon() {
        for language in languages {
            let (session, text) = pickedWord(in: language)
            let afterColon = String(text.dropLast()) + ":"
            XCTAssertFalse(session.request(textBeforeCursor: afterColon).offersNextWords, language.identifier)
            XCTAssertTrue(session.request(textBeforeCursor: String(text.dropLast()) + ";").offersNextWords, language.identifier)
        }
    }

    /// A session right after picking a word from the bar, and the text it left.
    private func pickedWord(in language: TypingLanguage) -> (PredictiveTypingSession, String) {
        let session = PredictiveTypingSession(language: language)
        let word = String(language.editLetters.prefix(4))
        let typed = String(word.dropLast())
        let edit = session.choiceEdit(SuggestionBar.Item(text: word, kind: .suggestion), textBeforeCursor: typed)
        return (session, String(typed.dropLast(edit.deleteCount)) + edit.insertText)
    }
}
