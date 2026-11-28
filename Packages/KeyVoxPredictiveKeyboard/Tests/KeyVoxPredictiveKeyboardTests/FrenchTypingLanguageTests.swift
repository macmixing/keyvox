import XCTest
@testable import KeyVoxPredictiveKeyboard

/// French's rules, as Apple's French (France) keyboard was measured typing them on iOS 27.2.
final class FrenchTypingLanguageTests: XCTestCase {
    private let quotes = TypingLanguage.french.quotes
    private let quoteKey = SmartQuotes.doubleQuote
    private let noBreakSpace = "\u{00A0}"

    func testFrenchShowsAzertyFrenchAndOffersApplesOtherLayoutsInOrder() throws {
        let language = TypingLanguage.french
        XCTAssertEqual(language.letterLayout.identifier, "AZERTY-French")
        XCTAssertEqual(language.alternativeLetterLayouts, ["AZERTY", "QWERTY-Accents", "QWERTY", "QWERTZ"])
        for identifier in language.alternativeLetterLayouts {
            XCTAssertEqual(try LetterKeyLayout.bundled(identifier: identifier).identifier, identifier)
        }
    }

    func testQuoteKeyTypesGuillemetsWithANoBreakSpaceInside() {
        // `"` → `« `, `oui "` → `oui « `, `oui"` → `oui »`, `""` → `« « `.
        XCTAssertEqual(quotes.text(for: quoteKey, after: nil), "«" + noBreakSpace)
        XCTAssertEqual(quotes.text(for: quoteKey, after: "oui "), "«" + noBreakSpace)
        XCTAssertEqual(quotes.text(for: quoteKey, after: "oui"), noBreakSpace + "»")
        XCTAssertEqual(quotes.text(for: quoteKey, after: "«" + noBreakSpace), "«" + noBreakSpace)
        XCTAssertEqual(quotes.text(for: quoteKey, after: "«" + noBreakSpace + "oui"), noBreakSpace + "»")
    }

    func testAQuotationTheQuoteKeyOpensKeepsTheSentenceStartWhereItIs() {
        // `"oui"` → `« Oui »`, and `oui "oui" oui` → `Oui « oui » oui`.
        XCTAssertTrue(TypingLanguage.french.startsSentence(after: "«" + noBreakSpace))
        XCTAssertFalse(TypingLanguage.french.startsSentence(after: "Oui «" + noBreakSpace))
        let context = TypingTextContext(textBeforeCursor: "Oui «" + noBreakSpace + "ou")
        XCTAssertEqual(context.currentWord, "ou")
        XCTAssertEqual(context.previousWords, ["Oui"])
    }

    func testAGuillemetPickedFromThePopupEndsTheSentenceStart() {
        // `«bonjour»` and `« bonjour »`, typed from the quote key's popup, stay lowercase.
        XCTAssertFalse(TypingLanguage.french.startsSentence(after: "«"))
        XCTAssertFalse(TypingLanguage.french.startsSentence(after: "« "))
        XCTAssertTrue(TypingLanguage.french.startsSentence(after: ""))
        // English reads every opening mark as before.
        for text in ["“", "«", "« ", "Yes. “"] {
            XCTAssertTrue(TypingLanguage.english.startsSentence(after: text), text)
        }
    }

    func testAPickedWordKeepsItsSpaceBeforeAQuestionMark() {
        // `Bonj`, the bar's `Bonjour`, then `?` → `Bonjour ?`; `.` still takes the space.
        for (separator, deleteCount) in [("?", 0), (".", 1)] {
            let session = PredictiveTypingSession(language: .french)
            let typed = "Bonj"
            let edit = session.choiceEdit(SuggestionBar.Item(text: "Bonjour", kind: .suggestion), textBeforeCursor: typed)
            let text = String(typed.dropLast(edit.deleteCount)) + edit.insertText
            XCTAssertEqual(
                session.wordBoundaryEdit(separator: separator, textBeforeCursor: text, result: nil).deleteCount,
                deleteCount,
                separator
            )
        }
    }

    func testALetterPickedFromAPopupKeepsItsWord() throws {
        // Apple keeps `pas trop à cœur`, `cœur`, `c’est mon cœur`, and `dans l’œil` with `œ` picked
        // from the `o` key's popup.
        let computer = PredictionComputer(engine: try PredictiveEngine(language: .french))
        let keys = KeyCenterMap(geometry: TypingLanguage.french.letterLayout.defaultGeometry)
        let offering = try HeldKeyCharacters.bundled(for: .french).letterKeysOfOfferedLetters
        for (before, word) in [("pas trop à ", "cœur"), ("", "cœur"), ("c’est mon ", "cœur"), ("dans l’", "œil")] {
            let session = PredictiveTypingSession(language: .french)
            var text = before
            for letter in word {
                text.append(letter)
                // A popup's letter counts as a tap on the key held to pick it.
                let center = try XCTUnwrap(keys.center(of: offering[letter] ?? letter))
                session.recordTap(at: center, textBeforeCursor: text)
            }
            let result = try computer.compute(session.request(textBeforeCursor: text))
            let edit = session.wordBoundaryEdit(separator: " ", textBeforeCursor: text, result: result)
            XCTAssertEqual(String(text.dropLast(edit.deleteCount)) + edit.insertText, text + " ", word)
        }
    }
}
