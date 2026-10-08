import XCTest
@testable import KeyVoxPredictiveKeyboard

/// What space does to a finished word, decided against the bundled language data: common
/// typos are fixed, apostrophes and capitals restored, and real words left as typed.
final class AutocorrectionTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
    }

    func testCommonTyposAreCorrected() throws {
        XCTAssertEqual(try autocorrection(typing: "teh"), "the")
        XCTAssertEqual(try autocorrection(typing: "i dont"), "don't")
    }

    func testMissingApostropheInImIsRestored() throws {
        XCTAssertEqual(try autocorrection(typing: "im"), "I'm")
        XCTAssertEqual(try autocorrection(typing: "Im"), "I'm")
        XCTAssertEqual(try autocorrection(typing: "yes im"), "I'm")
    }

    func testPronounIIsCapitalized() throws {
        XCTAssertEqual(try autocorrection(typing: "i"), "I")
        XCTAssertEqual(try autocorrection(typing: "then i'll"), "I'll")
    }

    func testEverydayWordsStayAsTyped() throws {
        for text in ["wtf", "that was lol", "good night", "the dogs"] {
            XCTAssertNil(try autocorrection(typing: text), "\(text) was changed")
        }
    }

    func testNamesTakeTheirCapitals() throws {
        XCTAssertEqual(try autocorrection(typing: "i met jennifer"), "Jennifer")
        XCTAssertEqual(try autocorrection(typing: "my new iphone"), "iPhone")
        XCTAssertEqual(try autocorrection(typing: "say hi to charlie"), "Charlie")
    }

    /// The space-bar replacement for the last typed word, with each letter tapped at its
    /// key's center.
    private func autocorrection(typing text: String) throws -> String? {
        let request = PredictiveTypingSession().request(textBeforeCursor: text)
        return try computer.compute(request).autocorrection
    }
}
