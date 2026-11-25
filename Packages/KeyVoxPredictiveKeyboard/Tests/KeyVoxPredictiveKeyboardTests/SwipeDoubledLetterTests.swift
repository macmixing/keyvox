import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A repeated letter is one key to a swipe, so a word with a doubled letter and its twin without
/// one ("too" and "to") are the same swipe; the words before decide between them, and a word with
/// a doubled letter wins wherever they call for it.
final class SwipeDoubledLetterTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try PredictiveEngine(language: .english))
    }

    func testTheSameSwipeIsTooOrToAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["me"]), "too")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["not"]), "too")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["want", "i"]), "to")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["is", "it"]), "to")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: []), "to", "a sentence starting")
    }

    func testTheSameSwipeIsOffOrOfAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "off", previousWords: ["turn"]), "off")
        XCTAssertEqual(try best(swipingKeysOf: "off", previousWords: ["one"]), "of")
    }

    func testTheSameSwipeIsGoodOrGodAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "good", previousWords: ["very"]), "good")
        XCTAssertEqual(try best(swipingKeysOf: "good", previousWords: ["my", "oh"]), "god")
    }

    func testWordsWithADoubledLetterWinWhereTheWordsBeforeCallForThem() throws {
        let words: [(word: String, previousWords: [String])] = [
            ("soon", ["as"]),
            ("been", ["have"]),
            ("see", ["can", "i"]),
            ("all", ["at"]),
            ("will", ["i"]),
            ("need", ["i"]),
            ("feel", ["i"]),
            ("look", ["a", "take"]),
            ("still", ["is", "it"]),
            ("little", ["a"]),
        ]
        for (word, previousWords) in words {
            XCTAssertEqual(try best(swipingKeysOf: word, previousWords: previousWords), word, "after \(previousWords)")
        }
    }

    /// The best word for a swipe through `word`'s keys, each repeated letter's key once, as a
    /// finger swipes it.
    private func best(swipingKeysOf word: String, previousWords: [String]) throws -> String? {
        let keys = word.reduce(into: "") { keys, letter in
            if keys.last != letter { keys.append(letter) }
        }
        return try computer.swipeWords(
            for: SwipePath.through(keys), previousWords: previousWords, wordCase: .asSpelled, limit: 4
        ).first
    }
}
