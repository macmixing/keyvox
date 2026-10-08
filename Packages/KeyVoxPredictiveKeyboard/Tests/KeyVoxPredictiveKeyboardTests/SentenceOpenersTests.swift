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

    func testGeneralOpenersWithoutAnEndingOfItsOwn() {
        XCTAssertEqual(openers.words(after: nil), ["i", "the", "he"])
        XCTAssertEqual(words(after: .lineBreak, ["they", "went"]), ["i", "the", "he"])
        XCTAssertEqual(words(after: .period, ["they", "went"]), ["i", "the", "he"])
    }

    private func words(after mark: SentenceEnding.Mark, _ words: [String]) -> [String] {
        openers.words(after: SentenceEnding(mark: mark, words: words))
    }
}
