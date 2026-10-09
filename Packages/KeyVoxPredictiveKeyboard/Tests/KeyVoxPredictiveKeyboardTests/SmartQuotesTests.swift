import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The apostrophe key and the quote key type what the system keyboard's keys type with smart
/// quotes on, measured on its number page and symbol page after each kind of character.
final class SmartQuotesTests: XCTestCase {
    private let apostrophe = SmartQuotes.apostrophe

    func testApostropheOpensAQuotationWhereOneCanBegin() {
        // A quotation opened earlier does not count: only the character before the cursor does.
        for before in [nil, "", "a ", "a\n", "(", "-", SmartQuotes.openingDoubleQuote, SmartQuotes.openingQuote + "a "] {
            XCTAssertEqual(
                SmartQuotes.text(for: apostrophe, after: before),
                SmartQuotes.openingQuote,
                "after \(String(describing: before))"
            )
        }
    }

    func testApostropheAfterWordsNumbersAndClosingMarks() {
        for before in ["a", "1", ")", ".", "$", SmartQuotes.openingQuote, "a" + apostrophe] {
            XCTAssertEqual(SmartQuotes.text(for: apostrophe, after: before), apostrophe, "after \(before)")
        }
    }

    func testQuoteKeyOpensAtTheStartOfTheText() {
        XCTAssertEqual(SmartQuotes.text(for: SmartQuotes.doubleQuote, after: nil), SmartQuotes.openingDoubleQuote)
        XCTAssertEqual(SmartQuotes.text(for: SmartQuotes.doubleQuote, after: ""), SmartQuotes.openingDoubleQuote)
    }

    func testOtherKeysTypeTheirOwnCharacter() {
        XCTAssertEqual(SmartQuotes.text(for: "-", after: "a "), "-")
    }
}
