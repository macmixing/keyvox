import XCTest
@testable import KeyVoxPredictiveKeyboard

/// While the user picks the bar's words in a row, the next-word bar always offers three words,
/// never leads with a word already picked unless it is a grammar word, never writes a three-word
/// phrase again, and writes something different each time from the same start.
final class RepeatedPicksTests: XCTestCase {
    private var engine: EnglishPredictiveEngine!
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        engine = try EnglishPredictiveEngine()
        computer = PredictionComputer(engine: engine)
    }

    func testPickedContentWordsAndPhrasesComeAfterTheOthersButStayOffered() {
        // "and the other side of the world and the", newest first.
        let picks = RepeatedPicks(
            pickedWords: ["the", "and", "world", "the", "of", "side", "other", "the", "and"],
            grammarWords: engine.grammarWords
        )
        XCTAssertTrue(picks.repeats("World", after: ["the", "and"]), "a content word already picked")
        XCTAssertTrue(picks.repeats("other", after: ["the", "and"]), "a phrase already picked")
        XCTAssertFalse(picks.repeats("of", after: ["same", "the"]), "a grammar word may come back in a new phrase")
        XCTAssertTrue(picks.repeats("of", after: ["side", "other"]), "but not in a phrase already picked")
        XCTAssertFalse(picks.repeats("same", after: ["the", "and"]))
        XCTAssertEqual(picks.ordering(["world", "same", "other"], after: ["the", "and"]), ["same", "world", "other"])
    }

    func testPickingFromEverySlotFromEveryLetterNeverRepeatsAndAlwaysOffersThreeWords() throws {
        for letter in "abcdefghijklmnopqrstuvwxyz" {
            for slot in [\SuggestionBar.leading, \SuggestionBar.primary, \SuggestionBar.trailing] {
                let text = try pick(from: String(letter), slot: slot, times: 40)
                let words = TypingTextContext.wordsNewestFirst(in: text).reversed().map(PersonalVocabulary.key)
                let phrases = (0...(words.count - 3)).map { words[$0..<($0 + 3)].joined(separator: " ") }
                XCTAssertEqual(phrases.count, Set(phrases).count, "\(letter): a phrase repeats in \(text)")
                let content = words.filter { engine.grammarWords.contains($0) == false }
                XCTAssertEqual(content.count, Set(content).count, "\(letter): a word repeats in \(text)")
            }
        }
    }

    func testPickingAgainFromTheSameStartWritesSomethingElse() throws {
        let texts = try (0..<5).map { _ in try pick(from: "g", slot: \.primary, times: 20) }
        XCTAssertGreaterThan(Set(texts).count, 1, "\(texts)")
    }

    func testAWordTheUserTypesEndsTheRunOfPicks() throws {
        let session = PredictiveTypingSession()
        let picked = try computer.compute(session.request(textBeforeCursor: "I "))
        let item = try XCTUnwrap(picked.bar.primary)
        let edit = session.choiceEdit(item, textBeforeCursor: "I ", result: picked)
        let afterPick = "I " + edit.insertText
        XCTAssertEqual(session.request(textBeforeCursor: afterPick).pickedWords, [item.text])
        XCTAssertEqual(session.request(textBeforeCursor: afterPick + "really ").pickedWords, [])
    }

    /// The text written by typing `start` and then picking the bar's `slot` word `times` times,
    /// the first pick completing `start` with the middle word, as the keyboard applies each pick.
    private func pick(from start: String, slot: KeyPath<SuggestionBar, SuggestionBar.Item?>, times: Int) throws -> String {
        let session = PredictiveTypingSession()
        var text = start
        for tap in 0...times {
            let result = try computer.compute(session.request(textBeforeCursor: text))
            let bar = result.bar
            if tap > 0 {
                XCTAssertEqual([bar.leading, bar.primary, bar.trailing].compactMap { $0 }.count, 3, "bar after \(text)")
            }
            let item = try XCTUnwrap(tap == 0 ? bar.primary : bar[keyPath: slot], "no word after \(text)")
            let edit = session.choiceEdit(item, textBeforeCursor: text, result: result)
            text = String(text.dropLast(edit.deleteCount)) + edit.insertText
            session.textDidChange(textBeforeCursor: text)
        }
        return text
    }
}
