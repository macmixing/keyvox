import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Typing remembers the corrections the user turns down, against the bundled language data:
/// undoing one keeps it off while the keyboard runs, keeping the typed word in the bar keeps it
/// off after a restart too, and choosing it again lets it apply. Unknown words the user keeps are
/// learned on their second use, as written, and dictionary words teach nothing but the capitals
/// the user gives them within a sentence.
final class RememberedCorrectionsTests: XCTestCase {
    private var computer: PredictionComputer!
    private let start = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
    }

    func testUndoneCorrectionStaysOffWhileTheKeyboardRuns() throws {
        let memory = TypingMemory()
        let session = PredictiveTypingSession(memory: memory, now: { self.start })
        let correction = try spaceCorrection(of: "teh", session: session)
        XCTAssertNotNil(correction)
        let space = session.wordBoundaryEdit(separator: " ", textBeforeCursor: "teh", result: try result(for: "teh", session: session))
        XCTAssertNotNil(session.backspaceEdit(textBeforeCursor: space.insertText))

        XCTAssertNil(try spaceCorrection(of: "teh", session: PredictiveTypingSession(memory: memory, now: { self.start })))
        let restarted = PredictiveTypingSession(memory: TypingMemory(saved: memory.saved), now: { self.start })
        XCTAssertEqual(try spaceCorrection(of: "teh", session: restarted), correction)
    }

    func testKeptTypedWordStaysOffAfterARestartUntilChosen() throws {
        let memory = TypingMemory()
        let session = PredictiveTypingSession(memory: memory, now: { self.start })
        let bar = try result(for: "teh", session: session)
        let correction = try XCTUnwrap(bar.autocorrection)
        _ = session.choiceEdit(SuggestionBar.Item(text: "teh", kind: .typed), textBeforeCursor: "teh", result: bar)

        let restarted = TypingMemory(saved: memory.saved)
        let later = PredictiveTypingSession(memory: restarted, now: { self.start.addingTimeInterval(60) })
        XCTAssertNil(try spaceCorrection(of: "teh", session: later))
        _ = later.choiceEdit(SuggestionBar.Item(text: correction, kind: .suggestion), textBeforeCursor: "teh")
        XCTAssertEqual(try spaceCorrection(of: "teh", session: later), correction)
    }

    func testCorrectionWaitingWithoutAutocorrectionIsNotTurnedDown() throws {
        let memory = TypingMemory()
        let session = PredictiveTypingSession(memory: memory, now: { self.start })
        let bar = try result(for: "teh", session: session)
        _ = session.choiceEdit(
            SuggestionBar.Item(text: "teh", kind: .typed),
            textBeforeCursor: "teh",
            result: bar,
            allowsAutocorrection: false
        )
        XCTAssertNotNil(try spaceCorrection(of: "teh", session: session))
    }

    func testUnknownWordKeptAsTypedIsLearnedOnItsSecondUseAsWritten() {
        let memory = TypingMemory()
        let session = PredictiveTypingSession(memory: memory, now: { self.start })
        for (use, text) in ["Zorbix", "it is zorbix"].enumerated() {
            XCTAssertFalse(memory.learnedWords.contains("zorbix"), "before use \(use + 1)")
            _ = session.wordBoundaryEdit(separator: " ", textBeforeCursor: text, result: unknownWordResult(for: text, session: session))
        }
        XCTAssertTrue(memory.learnedWords.contains("zorbix"))
        XCTAssertEqual(memory.learnedWords.uses["zorbix"]?.firstForm, "Zorbix", "a capital that starts a sentence is kept")
        XCTAssertEqual(memory.learnedWords.uses["zorbix"]?.previousWords, [ContextLanguageScorer.sentenceStart: 1, "is": 1])
    }

    func testKnownWordsAreNotCounted() throws {
        let memory = TypingMemory()
        let session = PredictiveTypingSession(memory: memory, now: { self.start })
        for _ in 0..<LearnedWords.usesToLearn {
            _ = session.wordBoundaryEdit(separator: " ", textBeforeCursor: "the dogs", result: try result(for: "the dogs", session: session))
        }
        XCTAssertTrue(memory.learnedWords.uses.isEmpty)
        XCTAssertTrue(memory.learnedCapitals.uses.isEmpty)
    }

    func testDictionaryWordWrittenWithCapitalsWithinASentenceTeachesItsCapitals() throws {
        let memory = TypingMemory()
        let session = PredictiveTypingSession(memory: memory, now: { self.start })
        let atStart = try result(for: "Rose", session: session)
        XCTAssertEqual(atStart.typedWordKind, .dictionaryWord)
        _ = session.wordBoundaryEdit(separator: " ", textBeforeCursor: "Rose", result: atStart)
        XCTAssertNil(memory.learnedCapitals.form(of: "rose"), "a capital that only starts a sentence teaches nothing")
        _ = session.wordBoundaryEdit(separator: " ", textBeforeCursor: "I met Rose", result: try result(for: "I met Rose", session: session))
        XCTAssertEqual(memory.learnedCapitals.form(of: "rose"), "Rose")
    }

    func testKnownNameTheDictionaryHasAsAnEverydayWordStillTeachesItsCapitals() throws {
        try computer.updateVocabulary(PersonalVocabulary(words: [], knownNames: ["Rose"], textReplacements: []))
        let memory = TypingMemory()
        let session = PredictiveTypingSession(memory: memory, now: { self.start })
        let named = try result(for: "I met Rose", session: session)
        XCTAssertEqual(named.typedWordKind, .dictionaryWord)
        _ = session.wordBoundaryEdit(separator: " ", textBeforeCursor: "I met Rose", result: named)
        XCTAssertEqual(memory.learnedCapitals.form(of: "rose"), "Rose")
    }

    private func result(for text: String, session: PredictiveTypingSession) throws -> PredictionResult {
        try computer.compute(session.request(textBeforeCursor: text))
    }

    /// What space would insert for the last word of `text`.
    private func spaceCorrection(of text: String, session: PredictiveTypingSession) throws -> String? {
        try result(for: text, session: session).autocorrection
    }

    /// A result for a word the keyboard does not know and leaves as typed.
    private func unknownWordResult(for text: String, session: PredictiveTypingSession) -> PredictionResult {
        let request = session.request(textBeforeCursor: text)
        return PredictionResult(
            request: request,
            bar: SuggestionBarComposer.compose(typedWord: request.currentWord, autocorrection: nil, rankedWords: []),
            autocorrection: nil,
            typedWordKind: .unknown
        )
    }
}
