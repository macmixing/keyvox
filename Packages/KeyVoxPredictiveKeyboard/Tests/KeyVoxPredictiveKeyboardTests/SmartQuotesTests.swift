import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The apostrophe key and the quote key type what the system keyboard's keys type with smart
/// quotes on, measured on its number page and symbol page after each kind of character.
final class SmartQuotesTests: XCTestCase {
    private let apostrophe = SmartQuotes.apostrophe
    private let quotes = TypingLanguage.english.quotes

    func testApostropheOpensAQuotationWhereOneCanBegin() {
        // A quotation opened earlier does not count: only the character before the cursor does.
        for before in [nil, "", "a ", "a\n", "(", "-", quotes.double.opening, quotes.single.opening + "a "] {
            XCTAssertEqual(
                quotes.text(for: apostrophe, after: before),
                quotes.single.opening,
                "after \(String(describing: before))"
            )
        }
    }

    func testApostropheAfterWordsNumbersAndClosingMarks() {
        for before in ["a", "1", ")", ".", "$", quotes.single.opening, "a" + apostrophe] {
            XCTAssertEqual(quotes.text(for: apostrophe, after: before), apostrophe, "after \(before)")
        }
    }

    func testQuoteKeyOpensAtTheStartOfTheText() {
        XCTAssertEqual(quotes.text(for: SmartQuotes.doubleQuote, after: nil), quotes.double.opening)
        XCTAssertEqual(quotes.text(for: SmartQuotes.doubleQuote, after: ""), quotes.double.opening)
    }

    func testOtherKeysTypeTheirOwnCharacter() {
        XCTAssertEqual(quotes.text(for: "-", after: "a "), "-")
    }
}
