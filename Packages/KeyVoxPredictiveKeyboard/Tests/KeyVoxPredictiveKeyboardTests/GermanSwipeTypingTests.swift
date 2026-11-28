import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Swiping German: the umlauts' own keys on Apple's German layout, and their vowels' keys on the
/// layouts without them.
final class GermanSwipeTypingTests: XCTestCase {
    func testGermanBundlesASwipeModel() {
        XCTAssertTrue(TypingLanguage.german.offersSwipeTyping)
        XCTAssertTrue(TypingLanguage.english.offersSwipeTyping)
    }

    func testAnUmlautWithAKeyOfItsOwnKeepsItInTheSwipeForm() throws {
        let german = try SwipeModelSettings.bundled(for: .german).formLetters
        XCTAssertEqual(SwipeLetterForm.form(of: "Über", letters: german), "über")
        XCTAssertEqual(SwipeLetterForm.form(of: "Straße", letters: german), "strasse")
        XCTAssertEqual(SwipeLetterForm.form(of: "Café", letters: german), "cafe")
        // English has no key for it, so its form folds the accent as before.
        let english = try SwipeModelSettings.bundled(for: .english).formLetters
        XCTAssertEqual(SwipeLetterForm.form(of: "Über", letters: english), "uber")
        XCTAssertEqual(SwipeLetterForm.form(of: "Über"), "uber")
    }

    func testASwipeThroughAnUmlautsKeyGivesTheWordWithIt() throws {
        XCTAssertEqual(try SwipedWord.best(swiping: "über", in: .german), "über")
        XCTAssertEqual(try SwipedWord.best(swiping: "für", in: .german), "für")
        XCTAssertEqual(try SwipedWord.best(swiping: "schön", in: .german), "schön")
    }

    func testOnALayoutWithoutUmlautKeysTheVowelsKeyGivesTheWordWithTheUmlaut() throws {
        let german = TypingLanguage.german
        for identifier in german.alternativeLetterLayouts {
            let language = try TypingLanguage.bundled(identifier: german.identifier, letterLayout: identifier)
            XCTAssertEqual(try SwipedWord.best(swiping: "fur", in: language), "für", identifier)
            XCTAssertEqual(try SwipedWord.best(swiping: "uber", in: language), "über", identifier)
        }
    }

    func testSwipesDecodeOnEveryLayoutGermanOffers() throws {
        let german = TypingLanguage.german
        for identifier in german.letterLayouts {
            let language = try TypingLanguage.bundled(identifier: german.identifier, letterLayout: identifier)
            XCTAssertEqual(try SwipedWord.best(swiping: "zeit", in: language), "Zeit", identifier)
        }
    }
}
