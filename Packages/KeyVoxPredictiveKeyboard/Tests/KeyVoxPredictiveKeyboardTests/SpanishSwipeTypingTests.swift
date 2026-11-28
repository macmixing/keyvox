import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Swiping Spanish: "ñ" on its own key on Apple's Spanish layout, and on the "n" key on the
/// layouts without one.
final class SpanishSwipeTypingTests: XCTestCase {
    func testSpanishBundlesASwipeModel() {
        XCTAssertTrue(TypingLanguage.spanish.offersSwipeTyping)
    }

    func testASwipeThroughTheEnyeKeyGivesTheWordWithIt() throws {
        XCTAssertEqual(try SwipedWord.best(swiping: "niño", in: .spanish), "niño")
        XCTAssertEqual(try SwipedWord.best(swiping: "mañana", in: .spanish), "mañana")
    }

    func testOnALayoutWithoutAnEnyeKeyTheNKeyGivesTheWordWithIt() throws {
        let spanish = TypingLanguage.spanish
        for identifier in spanish.alternativeLetterLayouts {
            let language = try TypingLanguage.bundled(identifier: spanish.identifier, letterLayout: identifier)
            XCTAssertEqual(try SwipedWord.best(swiping: "nino", in: language), "niño", identifier)
        }
    }

    func testSwipesDecodeOnEveryLayoutSpanishOffers() throws {
        let spanish = TypingLanguage.spanish
        for identifier in spanish.letterLayouts {
            let language = try TypingLanguage.bundled(identifier: spanish.identifier, letterLayout: identifier)
            XCTAssertEqual(try SwipedWord.best(swiping: "hola", in: language), "hola", identifier)
        }
    }
}
