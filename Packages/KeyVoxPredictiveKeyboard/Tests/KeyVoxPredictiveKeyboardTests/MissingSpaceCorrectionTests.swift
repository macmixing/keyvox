import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A word typed with its space missed, with or without typos in either word, is corrected
/// to the two words on space; a name the dictionary does not know is left as typed.
final class MissingSpaceCorrectionTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
    }

    func testMergedWordsWithTyposInBothWordsSplitAtSentenceStart() throws {
        // "probably" missing a letter, "works" with two letters swapped.
        XCTAssertEqual(try autocorrection(typing: "probalywroks"), "probably works")
    }

    func testMergedWordsWithTyposInBothWordsSplitMidSentence() throws {
        XCTAssertEqual(try autocorrection(typing: "it probalywroks"), "probably works")
    }

    func testMergedWordsWithoutTyposSplit() throws {
        XCTAssertEqual(try autocorrection(typing: "would that i hadmarried"), "had married")
    }

    func testMergedWordsWithTypoInFirstWordSplit() throws {
        XCTAssertEqual(try autocorrection(typing: "her namroften"), "name often")
    }

    func testMergedWordsWithTypoInSecondWordSplit() throws {
        XCTAssertEqual(try autocorrection(typing: "the bicycle is nltfor"), "not for")
    }

    func testUnknownNameTypedExactlyIsNotSplit() throws {
        let corrected = try autocorrection(typing: "i saw isoroku")
        XCTAssertFalse(corrected?.contains(" ") ?? false, "split into \(corrected ?? "")")
    }

    /// The space-bar replacement for the last typed word, lowercased, with each letter
    /// tapped at its key's center.
    private func autocorrection(typing text: String) throws -> String? {
        let request = PredictiveTypingSession().request(textBeforeCursor: text)
        return try computer.compute(request).autocorrection?.lowercased()
    }
}
