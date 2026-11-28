import Foundation
import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Every opener is scored by its likelihood after the previous sentence's ending, plus a boost
/// for that sentence's first word and one for each word in it; the best three are offered.
final class SentenceOpenersTests: XCTestCase {
    private var openers: SentenceOpeners!

    override func setUpWithError() throws {
        let model = """
        ending *\ti:-1.0 the:-1.5 he:-2.0 they:-3.0 how:-3.5 what:-4.0
        ending question\ti:-1.0 what:-1.6 the:-1.7 they:-3.0 how:-3.0 he:-4.0
        first question how\thow:2.5
        opening ^\thow:-0.5 what:-0.8 i:-3.0 the:-4.0 he:-5.0 they:-6.0
        word question they\tthey:2.5 he:-1.0

        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try model.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        openers = try SentenceOpeners(contentsOf: url)
    }

    func testEndingSetsTheOpenersLikelihood() {
        XCTAssertEqual(words(after: .question, ["is", "it", "ok"]), ["i", "what", "the"])
    }

    func testFirstWordBoostsItsOpeners() {
        XCTAssertEqual(words(after: .question, ["how", "are", "you"]), ["how", "i", "what"])
    }

    func testEveryWordInTheSentenceBoostsItsOpeners() {
        XCTAssertEqual(words(after: .question, ["did", "they", "go"]), ["they", "i", "what"])
    }

    func testASentenceOpeningMarkSetsTheOpenersLikelihoodInPlaceOfTheEnding() {
        XCTAssertEqual(openers.words(after: nil, openingMark: "^"), ["how", "what", "i"])
        let ending = SentenceEnding(mark: .question, words: ["did", "they", "go"])
        XCTAssertEqual(openers.words(after: ending, openingMark: "^"), ["how", "what", "i"])
        XCTAssertEqual(openers.words(after: ending, openingMark: "~"), openers.words(after: ending))
    }

    func testTheRequestNamesTheLanguagesOpeningMarkRightBeforeTheCursorAtASentenceStart() {
        let spanish = PredictiveTypingSession(language: .spanish)
        let marks = TypingLanguage.spanish.textRules.sentenceOpeningMarks.map(String.init)
        XCTAssertFalse(marks.isEmpty)
        for mark in marks {
            XCTAssertEqual(spanish.request(textBeforeCursor: mark).sentenceOpeningMark, mark)
            XCTAssertEqual(spanish.request(textBeforeCursor: "a. " + mark).sentenceOpeningMark, mark)
            XCTAssertNil(spanish.request(textBeforeCursor: "a, " + mark).sentenceOpeningMark)
            XCTAssertNil(spanish.request(textBeforeCursor: mark + "a").sentenceOpeningMark)
            XCTAssertNil(PredictiveTypingSession(language: .english).request(textBeforeCursor: mark).sentenceOpeningMark)
        }
    }

    func testGeneralOpenersWithoutAnEndingOfItsOwn() {
        XCTAssertEqual(openers.words(after: nil), ["i", "the", "he"])
        XCTAssertEqual(words(after: .lineBreak, ["they", "went"]), ["i", "the", "he"])
        XCTAssertEqual(words(after: .period, ["they", "went"]), ["i", "the", "he"])
    }

    private func words(after mark: SentenceEnding.Mark, _ words: [String]) -> [String] {
        openers.words(after: SentenceEnding(mark: mark, words: words))
    }
}
