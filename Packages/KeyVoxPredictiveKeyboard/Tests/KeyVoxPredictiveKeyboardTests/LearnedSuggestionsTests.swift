import XCTest
@testable import KeyVoxPredictiveKeyboard

/// What the keyboard learned shapes suggestions the way the system keyboard's learning does,
/// against the bundled language data: a learned word is offered after the keyboard's own words,
/// or first after a word it often follows, is never what space corrects or completes a word to,
/// is left as typed with the user's capitals once kept, is followed by everyday words, and a
/// dictionary word the user gives capitals shows them unless the words before call for the
/// everyday word.
final class LearnedSuggestionsTests: XCTestCase {
    private var computer: PredictionComputer!
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let learnedWord = "plantix"

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
        let unknown = try computer.compute(PredictiveTypingSession().request(textBeforeCursor: "we need \(learnedWord)"))
        XCTAssertEqual(unknown.typedWordKind, .unknown, "the test word must be one the keyboard does not know")
    }

    func testLearnedWordComesAfterTheKeyboardsOwnWordsOrFirstAfterAWordItOftenFollows() throws {
        let elsewhere = "we need plan"
        let followed = "i like plan"
        let before = (try bar(for: elsewhere), try bar(for: followed))
        try learn([learnedWord, learnedWord], after: "like")

        XCTAssertEqual(try bar(for: elsewhere), before.0)
        let after = try bar(for: followed)
        XCTAssertEqual(after.primary?.text, learnedWord)
        XCTAssertEqual(after.trailing?.text, before.1.primary?.text)
    }

    func testSpaceLeavesTheTypedLettersAloneWhereALearnedWordComesFirst() throws {
        let followed = "i like planti"
        XCTAssertNotNil(try autocorrection(of: followed))
        try learn([learnedWord, learnedWord], after: "like")
        XCTAssertNil(try autocorrection(of: followed))
        XCTAssertEqual(try bar(for: followed).primary?.text, learnedWord)
    }

    func testSpaceNeverCorrectsToOrCompletesALearnedWord() throws {
        let typo = "we need plantx"
        let start = "we need planti"
        let before = (try autocorrection(of: typo), try autocorrection(of: start))
        try learn([learnedWord, learnedWord], after: "like")

        XCTAssertEqual(try autocorrection(of: typo), before.0)
        XCTAssertEqual(try autocorrection(of: start), before.1)
    }

    func testLearnedWordIsLeftAsTypedWithTheUsersCapitalsOnceKept() throws {
        try learn([learnedWord, learnedWord], after: "like")
        XCTAssertNil(try autocorrection(of: "we need \(learnedWord)"))

        let capitalized = learnedWord.prefix(1).uppercased() + learnedWord.dropFirst()
        try learn([capitalized, capitalized, capitalized], after: "need")
        XCTAssertEqual(try autocorrection(of: "we need \(learnedWord)"), capitalized)
    }

    func testEverydayWordsFollowAWordTheBundledDataHasNothingToFollow() throws {
        let engine = try EnglishPredictiveEngine()
        let expected = { (wordBefore: String?) in
            SuggestionBarComposer.composeNextWords(
                engine.unknownWordFollowers.words(afterUnknownWordFollowing: wordBefore)
                    .map { WordCasing.capitalizingPronoun(engine.capitalizedSpellings.written($0)) }
            )
        }
        XCTAssertEqual(try bar(for: "i like \(learnedWord) "), expected("like"))
        XCTAssertEqual(try bar(for: "\(learnedWord) "), expected(nil))
    }

    func testCapitalsTheUserGivesADictionaryWordShowUnlessTheWordsBeforeCallForTheEverydayWord() throws {
        let engine = try EnglishPredictiveEngine()
        let lift = { (word: String, before: String) throws -> Double in
            let analysis = try engine.analyze(word: word, previousWords: [before])
            return analysis.precedingPairObserved ? analysis.precedingLogProbability - analysis.unigramLogProbability : -.infinity
        }
        XCTAssertLessThan(try lift("rose", "met"), PredictionComputer.everydayWordContextLogLift)
        XCTAssertGreaterThanOrEqual(try lift("rose", "red"), PredictionComputer.everydayWordContextLogLift)
        let memory = TypingMemory()
        memory.recordCapitalUse(of: "Rose", at: start)
        try computer.updateLearnedWords(memory.learnedVocabulary)

        XCTAssertTrue(try bar(for: "i met ros").texts.contains("Rose"))
        XCTAssertTrue(try bar(for: "a red ros").texts.contains("rose"))
        XCTAssertNil(try autocorrection(of: "i met rose"), "the typed word is never changed")
    }

    /// Teaches the computer `forms`, written in order after `previousWord`, on top of what it
    /// learned before in this test.
    private func learn(_ forms: [String], after previousWord: String) throws {
        for form in forms {
            memory.recordUse(of: form, after: previousWord, at: start)
        }
        try computer.updateLearnedWords(memory.learnedVocabulary)
    }

    private let memory = TypingMemory()

    private func bar(for text: String) throws -> SuggestionBar {
        try computer.compute(PredictiveTypingSession().request(textBeforeCursor: text)).bar
    }

    private func autocorrection(of text: String) throws -> String? {
        try computer.compute(PredictiveTypingSession().request(textBeforeCursor: text)).autocorrection
    }
}

private extension SuggestionBar {
    var texts: [String] {
        [leading, primary, trailing].compactMap { $0?.text }
    }
}
