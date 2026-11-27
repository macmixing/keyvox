import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A repeated letter is one key to a swipe, so a word with a doubled letter and its twin without
/// one ("too" and "to") are the same key path. Circling a letter's key, or squiggling over it,
/// doubles it whatever the words before; without a circle, the scores and the words before choose between lexicon words, and a
/// letter only the user's own words double is never added.
final class SwipeDoubledLetterTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try PredictiveEngine(language: .english))
    }

    func testTheSameSwipeIsTooOrToAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["me"]), "too", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["me"], circlingDoubles: 2), "too")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["not"]), "too", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["not"], circlingDoubles: 2), "too")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["want", "i"]), "to")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: ["is", "it"]), "to")
        XCTAssertEqual(try best(swipingKeysOf: "too", previousWords: []), "to", "a sentence starting")
    }

    func testTheSameSwipeIsOffOrOfAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "off", previousWords: ["turn"]), "off", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "off", previousWords: ["turn"], circlingDoubles: 2), "off")
        XCTAssertEqual(try best(swipingKeysOf: "off", previousWords: ["one"]), "of")
    }

    func testTheSameSwipeIsGoodOrGodAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "good", previousWords: ["very"]), "good", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "good", previousWords: ["very"], circlingDoubles: 2), "good")
        XCTAssertEqual(try best(swipingKeysOf: "good", previousWords: ["my", "oh"]), "god")
    }

    func testTheSameSwipeIsSonOrSoonAsTheWordsBeforeCallForIt() throws {
        XCTAssertEqual(try best(swipingKeysOf: "soon", previousWords: ["as"]), "soon", "no circle")
        XCTAssertEqual(try best(swipingKeysOf: "soon", previousWords: ["as"], circlingDoubles: 2), "soon")
        XCTAssertEqual(try best(swipingKeysOf: "soon", previousWords: ["my"]), "son", "no circle")
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

    func testACircleAtALetterAWordAlreadyDoublesKeepsItDoubled() throws {
        for word in ["class", "actress"] {
            XCTAssertEqual(try best(swipingKeysOf: word, previousWords: [], loopingAtDoubles: true)?.lowercased(), word)
        }
    }

    func testACircleDoublesALetterButNeverTriplesItWhereAllThreeAreWords() throws {
        let engine = try PredictiveEngine(language: .english)
        let forms = Set(try SwipeVocabulary.lexiconWords(of: engine).map { SwipeLetterForm.form(of: $0.spelling) })
        // Every word doubled at a letter it has once, whose tripled form is a word too, among words
        // with no letter three times already, which a circle gives nothing for.
        var families: [String: String] = [:]
        for single in forms {
            let letters = Array(single)
            guard letters.indices.dropFirst(2).allSatisfy({ letters[$0] != letters[$0 - 1] || letters[$0] != letters[$0 - 2] }) else { continue }
            for index in letters.indices
            where (index == 0 || letters[index - 1] != letters[index])
                && (index == letters.count - 1 || letters[index + 1] != letters[index]) {
                var doubled = letters, tripled = letters
                doubled.insert(letters[index], at: index)
                tripled.insert(contentsOf: [letters[index], letters[index]], at: index)
                if forms.contains(String(doubled)), forms.contains(String(tripled)) {
                    families[String(doubled)] = String(tripled)
                }
            }
        }
        XCTAssertFalse(families.isEmpty, "the lexicon has letters once, twice, and three times")
        let keyIndex = try SwipeModelSettings.bundled(for: .english).keyIndex
        var onTheirKeyPath = 0
        for (doubled, tripled) in families.sorted(by: { $0.key < $1.key }) {
            let swiped = try best(swipingKeysOf: doubled, previousWords: [], loopingAtDoubles: true).map(SwipeLetterForm.form(of:))
            XCTAssertNotEqual(swiped, tripled, "a circle at \(doubled)")
            // A swipe the model reads as another word altogether, as very short ones can be, is not the circle's.
            guard let swiped, SwipeLetterForm.keyPath(of: swiped, keyIndex: keyIndex, keepsDoubleLetters: false)
                == SwipeLetterForm.keyPath(of: doubled, keyIndex: keyIndex, keepsDoubleLetters: false) else { continue }
            onTheirKeyPath += 1
            XCTAssertEqual(swiped, doubled, "a circle at \(doubled)")
        }
        XCTAssertGreaterThan(onTheirKeyPath, 0)
    }

    func testCirclingEitherDoubledLetterOfAWordWithTwoKeepsBoth() throws {
        let word = "possess"
        let doubles = Set(word.indices.dropFirst().filter { word[word.index(before: $0)] == word[$0] }.map { word.distance(from: word.startIndex, to: $0) })
        var letters = ""
        var keyOfLetter: [Int] = []
        for letter in word {
            if letters.last != letter { letters.append(letter) }
            keyOfLetter.append(letters.count - 1)
        }
        for circled in doubles.map({ keyOfLetter[$0] }) {
            let swiped = try computer.swipeWords(
                for: SwipePath.through(letters, loopingAt: [circled]), previousWords: [], wordCase: .asSpelled, limit: 1
            ).first
            XCTAssertEqual(swiped, word, "circled at key \(circled) only")
        }
    }

    /// A word whose letter a loop asks for doubled keeps that credit against a twin with it tripled,
    /// however much more often the tripled one is written.
    func testACircledDoubleOutranksACommonerTripledTwin() throws {
        let engine = try PredictiveEngine(language: .english)
        let decoder = try SwipeWordDecoder(language: .english)
        let keys = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)
        // A made-up word with its last letter once, twice, and three times, the tripled one written
        // far more often than the misspelling ratio asks.
        let single = "zqx", doubled = "zqxx", tripled = "zqxxx"
        let frequency: [String: Double] = [single: -20, doubled: -10, tripled: 0]
        let path = SwipePath.through(single, loopingAt: [2])
        let emissions = try XCTUnwrap(decoder.emissions(for: path, keys: keys))
        let candidates = try decoder.candidates(
            emissions: emissions,
            personal: decoder.personalLexicon([single, doubled, tripled]),
            contextLift: nil,
            hasWordsBefore: false,
            doublingKeys: { keyPath in decoder.doublingKeys(path: path, keyPath: keyPath, keys: keys) },
            twinFacts: { spelling in frequency[spelling].map { SwipeTwinFacts(logFrequency: $0) } ?? SwipeTwinFacts(spelling: spelling, engine: engine) }
        ).map(\.spelling)
        let place = { (word: String) in try XCTUnwrap(candidates.firstIndex(of: word), "\(word) was weighed") }
        XCTAssertLessThan(try place(doubled), try place(tripled))
        XCTAssertLessThan(try place(doubled), try place(single))
    }

    /// A loop read at a letter asks for a rare word doubling it; a word on the same keys doubling
    /// another letter, where no loop was read, wins when it is written 50 times as often.
    func testALoopLosesToAWordDoublingAnotherLetterWrittenFiftyTimesAsOften() throws {
        let cases: [(keys: String, looped: Int, word: String)] = [("droped", 2, "dropped"), ("rom", 2, "room")]
        for (keys, looped, word) in cases {
            let swiped = try computer.swipeWords(
                for: SwipePath.through(keys, loopingAt: [looped]), previousWords: [], wordCase: .asSpelled, limit: 1
            ).first
            XCTAssertEqual(swiped, word, "a loop at \(Array(keys)[looped]) in \(keys)")
        }
    }

    func testACircleAtOneLetterNeverAddsAnotherTripledWithoutOne() throws {
        for previousWords in [[], ["ok"]] as [[String]] {
            let swiped = try computer.swipeWords(
                for: SwipePath.through("yes", loopingAt: [1]), previousWords: previousWords, wordCase: .asSpelled, limit: 1
            ).first
            XCTAssertEqual(swiped?.lowercased(), "yes", "circled at e after \(previousWords)")
        }
    }

    /// Without a circle, a twin written 50 times as often as the other wins whatever the words
    /// before, so a sentence that suits the rarer one never adds a letter people do not mean.
    func testWithoutACircleAFarCommonerTwinWinsWhateverTheWordsBefore() throws {
        XCTAssertEqual(try best(swipingKeysOf: "is", previousWords: ["station", "the"]), "is")
        XCTAssertEqual(try best(swipingKeysOf: "is", previousWords: ["station"]), "is")
    }

    func testWithoutACircleANameKeepsItsLettersOverACommonerTwin() throws {
        for word in ["mary", "paris", "anderson", "mr"] {
            XCTAssertEqual(try best(swipingKeysOf: word, previousWords: [])?.lowercased(), word, "no circle")
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

    func testSquigglingOverTheDoubledLetterGivesTheWordWhateverTheWordsBefore() throws {
        let contexts: [[String]] = [[], ["want", "i"], ["is", "it"], ["one"], ["my", "oh"]]
        for word in ["too", "soon", "off", "all", "good", "see", "been", "will", "still", "little"] {
            for previousWords in contexts {
                XCTAssertEqual(
                    try best(swipingKeysOf: word, previousWords: previousWords, squigglingAtDoubles: true),
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
    /// circling it `circlingDoubles` times, or squiggling over it when `squigglingAtDoubles`.
    private func best(
        swipingKeysOf word: String,
        previousWords: [String],
        loopingAtDoubles: Bool = false,
        circlingDoubles: Double? = nil,
        squigglingAtDoubles: Bool = false
    ) throws -> String? {
        var keys = ""
        var loops: Set<Int> = []
        var squiggles: Set<Int> = []
        for letter in word {
            if keys.last == letter {
                if loopingAtDoubles || circlingDoubles != nil { loops.insert(keys.count - 1) }
                if squigglingAtDoubles { squiggles.insert(keys.count - 1) }
            } else {
                keys.append(letter)
            }
        }
        return try computer.swipeWords(
            for: SwipePath.through(keys, loopingAt: loops, circles: circlingDoubles ?? 1, squigglingAt: squiggles),
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
