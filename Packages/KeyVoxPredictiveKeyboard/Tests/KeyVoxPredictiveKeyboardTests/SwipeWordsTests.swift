import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A swipe reaches every word typing reaches, written as typing writes it: the bundled
/// dictionary's words, the user's KeyVox Dictionary entries, contact names with their capitals,
/// text replacement shortcuts expanded, learned words, and the capitals the user gives a
/// dictionary word; the shift state carries over as it does to typed letters.
final class SwipeWordsTests: XCTestCase {
    private var engine: PredictiveEngine!
    private var computer: PredictionComputer!
    private let start = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        engine = try PredictiveEngine(language: .english)
        computer = PredictionComputer(engine: engine)
    }

    func testADictionaryWordDecodesToItself() throws {
        XCTAssertEqual(try best("hello"), "hello")
        XCTAssertEqual(try best("keyboard", previousWords: ["the"]), "keyboard")
    }

    func testAKeyVoxDictionaryEntryDecodesWrittenTheUsersWay() throws {
        try requireUnknown("keyvox")
        try computer.updateVocabulary(PersonalVocabulary(words: ["KeyVox"], textReplacements: []))
        XCTAssertEqual(try best("keyvox"), "KeyVox")
    }

    func testAContactNameDecodesWithItsCapitals() throws {
        try requireUnknown("esposito")
        try computer.updateVocabulary(PersonalVocabulary(words: [], knownNames: ["Esposito"], textReplacements: []))
        XCTAssertEqual(try best("esposito", previousWords: ["dom"]), "Esposito")
    }

    func testATextReplacementShortcutExpands() throws {
        try requireUnknown("omw")
        try computer.updateVocabulary(PersonalVocabulary(
            words: [],
            textReplacements: [PersonalVocabulary.TextReplacement(shortcut: "omw", expansion: "On my way!")]
        ))
        XCTAssertEqual(try best("omw"), "On my way!")
    }

    func testALearnedWordDecodesOnceTheBarOffersIt() throws {
        try requireUnknown("plantix")
        let memory = TypingMemory()
        for _ in 0..<LearnedWords.usesToLearn {
            memory.recordUse(of: "plantix", after: nil, at: start)
        }
        try computer.updateLearnedWords(memory.learnedVocabulary)
        XCTAssertEqual(try best("plantix"), "plantix")
    }

    func testALearnedCapitalAppliesUnlessTheWordsBeforeCallForTheEverydayWord() throws {
        let memory = TypingMemory()
        memory.recordCapitalUse(of: "Rose", at: start)
        try computer.updateLearnedWords(memory.learnedVocabulary)
        XCTAssertEqual(try best("rose", previousWords: ["met"]), "Rose")
        XCTAssertEqual(try best("rose", previousWords: ["red"]), "rose")
    }

    func testTheShiftStateCarriesOverAsToTypedLetters() throws {
        XCTAssertEqual(try best("hello", wordCase: .capitalized), "Hello")
        XCTAssertEqual(try best("hello", wordCase: .allCapitals), "HELLO")
        XCTAssertEqual(try best("i"), "I")
    }

    func testTheUsersWordsAreSearchedOnlyAsTypingSearchesThem() throws {
        let memory = TypingMemory()
        memory.recordUse(of: "plantix", after: nil, at: start)
        let vocabulary = PersonalVocabulary(
            words: ["Big Dictation"],
            knownNames: ["Esposito"],
            textReplacements: [PersonalVocabulary.TextReplacement(shortcut: "omw", expansion: "On my way!")]
        )
        let words = PredictionComputer.swipePersonalWords(vocabulary: vocabulary, learned: memory.learnedVocabulary)
        XCTAssertEqual(words, ["Big", "Dictation", "omw"], "a learned word joins once the bar offers it")
    }

    private func best(
        _ word: String,
        previousWords: [String] = [],
        wordCase: SwipeWordCase = .asSpelled
    ) throws -> String? {
        try computer.swipeWords(
            for: SwipePath.through(word), previousWords: previousWords, wordCase: wordCase, limit: 4
        ).first
    }

    private func requireUnknown(_ word: String) throws {
        XCTAssertFalse(try engine.analyze(word: word).wordIsValid, "the test word must be one the dictionary lacks")
    }
}
