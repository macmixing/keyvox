import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The sentence before a new one is read the way the language data is built: all its words,
/// its last mark naming how it ended, a line break only when no mark comes before it, and an
/// ellipsis a pause rather than an ending.
final class SentenceEndingTests: XCTestCase {
    func testQuestionKeepsItsWords() {
        XCTAssertEqual(
            SentenceEnding(before: "How are you? "),
            SentenceEnding(mark: .question, words: ["how", "are", "you"])
        )
    }

    func testMarkBeforeALineBreakNamesTheEnding() {
        XCTAssertEqual(SentenceEnding(before: "Hi!\n")?.mark, .exclamation)
        XCTAssertEqual(SentenceEnding(before: "See you\n")?.mark, .lineBreak)
    }

    func testOnlyTheLastSentenceCounts() {
        XCTAssertEqual(
            SentenceEnding(before: "Done. 5 hi! "),
            SentenceEnding(mark: .exclamation, words: ["hi"])
        )
    }

    func testWordsAreLowercasedWithStraightApostrophes() {
        XCTAssertEqual(
            SentenceEnding(before: "I CAN’T. "),
            SentenceEnding(mark: .period, words: ["i", "can't"])
        )
    }

    func testFirstWordOfTheNewSentenceDoesNotChangeTheEnding() {
        XCTAssertEqual(
            SentenceEnding(before: "Hi there. Ho"),
            SentenceEnding(mark: .period, words: ["hi", "there"])
        )
    }

    func testNoEndingWithoutAnEarlierSentence() {
        XCTAssertNil(SentenceEnding(before: ""))
        XCTAssertNil(SentenceEnding(before: "Hello "))
        XCTAssertNil(SentenceEnding(before: "Wait... "))
        XCTAssertNil(SentenceEnding(before: "123. "))
    }
}
