import Foundation
import XCTest
@testable import KeyVoxEmoji

/// The suggestion bar's emoji for a word: the data's emoji in its order, for the word compared
/// without case or accents, and none for anything but one word.
final class EmojiPredictionsTests: XCTestCase {
    func testAWordGetsItsEmojiInTheDataOrder() throws {
        let predictions = try Self.predictions("dog\t🐕 🐶\npizza\t🍕\n")
        XCTAssertEqual(predictions.emoji(for: "dog"), ["🐕", "🐶"])
        XCTAssertEqual(predictions.emoji(for: "pizza"), ["🍕"])
    }

    func testCaseAndAccentsDoNotMatter() throws {
        let predictions = try Self.predictions("cafe\t☕️\n")
        XCTAssertEqual(predictions.emoji(for: "Café"), ["☕️"])
    }

    func testOnlyOneWholeWordGetsEmoji() throws {
        let predictions = try Self.predictions("dog\t🐕\n")
        XCTAssertEqual(predictions.emoji(for: "do"), [])
        XCTAssertEqual(predictions.emoji(for: "hot dog"), [])
        XCTAssertEqual(predictions.emoji(for: ""), [])
    }

    func testDataWithoutEmojiIsRejected() throws {
        XCTAssertThrowsError(try Self.predictions("dog\t\n")) { error in
            XCTAssertEqual(error as? EmojiDataError, .invalidPredictions(line: 1))
        }
    }

    private static func predictions(_ text: String) throws -> EmojiPredictions {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        return try EmojiPredictions(contentsOf: url)
    }
}
