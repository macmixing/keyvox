import XCTest
@testable import KeyVoxPredictiveKeyboard

/// French's rules, as Apple's French (France) keyboard was measured typing them on iOS 27.2
/// (`~/KeyVoxLanguageData/apple-languages`).
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
        XCTAssertTrue(TypingTextContext.startsSentence(after: "«" + noBreakSpace))
        XCTAssertFalse(TypingTextContext.startsSentence(after: "Oui «" + noBreakSpace))
        let context = TypingTextContext(textBeforeCursor: "Oui «" + noBreakSpace + "ou")
        XCTAssertEqual(context.currentWord, "ou")
        XCTAssertEqual(context.previousWords, ["Oui"])
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

    func testFrenchHasNoSwipeModelSoItIsTypedByTappingAlone() throws {
        XCTAssertFalse(TypingLanguage.french.offersSwipeTyping)
        XCTAssertTrue(TypingLanguage.english.offersSwipeTyping)
        let computer = PredictionComputer(engine: try PredictiveEngine(language: .french))
        let path = SwipePath.through("bonjour", on: TypingLanguage.french.letterLayout)
        XCTAssertEqual(try computer.swipeWords(for: path, previousWords: [], wordCase: .asSpelled, limit: 4), [])
    }
}
