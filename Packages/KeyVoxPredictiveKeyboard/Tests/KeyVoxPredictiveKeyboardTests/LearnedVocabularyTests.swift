import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A learned word typed without capitals gets the user's first capitals once they keep them, a
/// typing with only a first capital gets all capitals when the user first wrote it that way, as
/// on the system keyboard, and other typings stay as typed.
final class LearnedVocabularyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testTypingWithoutCapitalsGetsTheCapitalsOnlyOnceTheyAreKept() throws {
        XCTAssertEqual(try word(["Zorbix", "zorbix"]).written(ofTyped: "zorbix"), "zorbix")
        XCTAssertEqual(try word(["Zorbix", "Zorbix"]).written(ofTyped: "zorbix"), "Zorbix")
    }

    func testFirstCapitalTypingGetsAllCapitalsWhenFirstWrittenThatWay() throws {
        XCTAssertEqual(try word(["ZORBIX", "zorbix"]).written(ofTyped: "Zorbix"), "ZORBIX")
        XCTAssertEqual(try word(["Zorbix", "ZORBIX"]).written(ofTyped: "Zorbix"), "Zorbix")
        XCTAssertEqual(try word(["ZORBIX", "ZORBIX"]).written(ofTyped: "ZoRbix"), "ZoRbix")
    }

    func testOnlyLearnedWordsAreUsed() {
        var words = LearnedWords()
        words.recordUse(of: "zorbix", after: nil, at: start)
        XCTAssertNil(LearnedVocabulary(learnedWords: words, learnedCapitals: LearnedCapitals()).word("zorbix"))
    }

    /// The learned word after `forms`, written in order.
    private func word(_ forms: [String]) throws -> LearnedVocabulary.Word {
        var words = LearnedWords()
        for form in forms {
            words.recordUse(of: form, after: nil, at: start)
        }
        return try XCTUnwrap(LearnedVocabulary(learnedWords: words, learnedCapitals: LearnedCapitals()).word(forms[0]))
    }
}
