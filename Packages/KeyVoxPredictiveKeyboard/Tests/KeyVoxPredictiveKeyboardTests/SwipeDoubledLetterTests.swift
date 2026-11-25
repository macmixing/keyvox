import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A repeated letter is one key to a swipe, so a word with a doubled letter and its twin without
/// one ("too" and "to") are the same key path. Circling a letter's key doubles it whatever the words
/// before, and no circle never adds a letter: without one, the single twin wins wherever it is a
/// word people mean, and a word without such a twin comes out doubled as before.
final class SwipeDoubledLetterTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try PredictiveEngine(language: .english))
    }

    func testTheSameSwipeIsTooOrToAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["me"]), "to", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["me"], circlingDoubles: 2), "too")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["not"]), "to", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["not"], circlingDoubles: 2), "too")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["want", "i"]), "to")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["is", "it"]), "to")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: []), "to", "a sentence starting")
    }

    func testTheSameSwipeIsOffOrOfAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "off", previousWords: ["turn"]), "of", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "off", previousWords: ["turn"], circlingDoubles: 2), "off")
        XCTAssertEqual(try best(swipingKeysOf: "off", previousWords: ["one"]), "of")
    }

    func testTheSameSwipeIsGoodOrGodAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "good", previousWords: ["very"]), "god", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "good", previousWords: ["very"], circlingDoubles: 2), "good")
        XCTAssertEqual(try best(swipingKeysOf: "good", previousWords: ["my", "oh"]), "god")
    }

    func testTheSameSwipeIsSonOrSoonAsTheCircleAsksForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "soon", previousWords: ["as"]), "son", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "soon", previousWords: ["as"], circlingDoubles: 2), "soon")
    }

    func testADoubleCircleGivesAContactsDoubledNameAndNoCircleTheWord() throws {
        try computer.updateVocabulary(PersonalVocabulary(words: [], knownNames: ["Ameeta", "Mann"], textReplacements: []))
        for previousWords in [[], ["but"], ["this"]] as [[String]] {
            XCTAssertEqual(try best(swipingKeysOf: "mann", previousWords: previousWords), "man", "no circle after \(previousWords)")
            XCTAssertEqual(
                try best(swipingKeysOf: "mann", previousWords: previousWords, circlingDoubles: 2),
                "Mann",
                "a double circle after \(previousWords)"
            )
        }
    }

    func testWordsWithADoubledLetterWinWhereTheWordsBeforeCallForThem() throws {
        let words: [(word: String, previousWords: [String])] = [
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

    func testLoopingAroundTheDoubledLetterGivesTheWordWhateverTheWordsBefore() throws {
        let contexts: [[String]] = [[], ["want", "i"], ["is", "it"], ["one"], ["my", "oh"]]
        for word in ["too", "soon", "off", "all", "good", "see", "been", "will", "still", "little"] {
            for previousWords in contexts {
                XCTAssertEqual(
                    try best(swipingKeysOf: word, previousWords: previousWords, loopingAtDoubles: true),
                    word,
                    "after \(previousWords)"
                )
            }
        }
    }

    func testALoopAroundAKeyIsDetectedThere() throws {
        XCTAssertEqual(try loopedKeys(swiping: "to", loopingAt: [1]), [false, true])
        XCTAssertEqual(try loopedKeys(swiping: "son", loopingAt: [1]), [false, true, false])
        XCTAssertEqual(try loopedKeys(swiping: "to"), [false, false])
    }

    func testCornersAndTurnsAreNotLoops() throws {
        for keys in ["tag", "pal", "zap", "the", "qwerty", "keyboard", "mop"] {
            XCTAssertFalse(try loopedKeys(swiping: keys).contains(true), keys)
        }
    }

    /// The best word for a swipe through `word`'s keys, each repeated letter's key once, as a
    /// finger swipes it, looping around each doubled letter's key when `loopingAtDoubles`, or
    /// circling it `circlingDoubles` times.
    private func best(
        swipingKeysOf word: String,
        previousWords: [String],
        loopingAtDoubles: Bool = false,
        circlingDoubles: Double? = nil
    ) throws -> String? {
        var keys = ""
        var loops: Set<Int> = []
        for letter in word {
            if keys.last == letter {
                if loopingAtDoubles || circlingDoubles != nil { loops.insert(keys.count - 1) }
            } else {
                keys.append(letter)
            }
        }
        return try computer.swipeWords(
            for: SwipePath.through(keys, loopingAt: loops, circles: circlingDoubles ?? 1),
            previousWords: previousWords,
            wordCase: .asSpelled,
            limit: 4
        ).first
    }

    /// For each of `keys`, whether a swipe through them, looping at `loops`, loops around it.
    private func loopedKeys(swiping keys: String, loopingAt loops: Set<Int> = []) throws -> [Bool] {
        let map = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)
        let settings = try XCTUnwrap(SwipeModelSettings.bundled(for: .english).loops)
        return try XCTUnwrap(SwipeKeyLoop.loopedKeys(
            path: SwipePath.through(keys, loopingAt: loops),
            centers: keys.compactMap { map.center(of: $0) },
            pitch: Double(map.pitch.width),
            settings: settings
        ))
    }
}
