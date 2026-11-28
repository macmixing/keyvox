import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Swiping French: its letters on every layout it offers, and "œ", which no key types, swiped as
/// the "o" and "e" people swipe it as.
final class FrenchSwipeTypingTests: XCTestCase {
    func testFrenchBundlesASwipeModel() {
        XCTAssertTrue(TypingLanguage.french.offersSwipeTyping)
    }

    func testAnOeLigatureIsSwipedAsItsTwoLetters() throws {
        let french = try SwipeModelSettings.bundled(for: .french).formLetters
        XCTAssertEqual(SwipeLetterForm.form(of: "Cœur", letters: french), "coeur")
        XCTAssertEqual(SwipeLetterForm.form(of: "élève", letters: french), "eleve")
        // English spells no letter otherwise, so the ligature stays a letter no key types.
        XCTAssertEqual(SwipeLetterForm.form(of: "cœur", letters: try SwipeModelSettings.bundled(for: .english).formLetters), "cœur")
        XCTAssertEqual(try SwipedWord.best(swiping: "oeil", in: .french), "œil")
    }

    func testSwipesDecodeOnEveryLayoutFrenchOffers() throws {
        let french = TypingLanguage.french
        for identifier in french.letterLayouts {
            let language = try TypingLanguage.bundled(identifier: french.identifier, letterLayout: identifier)
            XCTAssertEqual(try SwipedWord.best(swiping: "bonjour", in: language), "bonjour", identifier)
        }
    }
}
