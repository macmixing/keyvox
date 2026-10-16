import Foundation
import XCTest
@testable import KeyVoxEmoji

/// Search finds emoji as the system keyboard's search was seen finding them: by every searched
/// word starting one of the emoji's words, whole words first, then in the data's order.
final class EmojiSearchTests: XCTestCase {
    func testEveryCatalogEmojiIsFoundByItsName() throws {
        let search = try EmojiSearch.bundled()
        for emoji in try EmojiCatalog.bundled().sections.flatMap(\.emoji) {
            XCTAssertTrue(search.results(for: emoji.name).contains(emoji.text), emoji.name)
        }
    }

    func testWholeWordsComeBeforeWordStartsThenTheDataOrder() throws {
        let search = try Self.search([
            ("first", "alpha beta"),
            ("second", "alphabet"),
            ("third", "alpha"),
        ])
        XCTAssertEqual(search.results(for: "alpha"), ["first", "third", "second"])
        XCTAssertEqual(search.results(for: "alp"), ["first", "second", "third"])
    }

    func testEverySearchedWordMustStartAWordInAnyOrder() throws {
        let search = try Self.search([
            ("both", "alpha beta"),
            ("one", "alpha gamma"),
        ])
        XCTAssertEqual(search.results(for: "beta alpha"), ["both"])
        XCTAssertEqual(search.results(for: "alpha be"), ["both"])
        XCTAssertEqual(search.results(for: "alpha delta"), [])
    }

    func testEmojiGivenFirstComeAheadOfTheResultsOnce() throws {
        let search = try Self.search([
            ("first", "alpha"),
            ("second", "alpha"),
        ])
        XCTAssertEqual(search.results(for: "alpha", first: ["second", "given"]), ["second", "given", "first"])
        XCTAssertEqual(search.results(for: "alpha", first: []), ["first", "second"])
    }

    func testCaseAndAccentsDoNotMatter() throws {
        let search = try Self.search([("found", "cafe")])
        XCTAssertEqual(search.results(for: "CAFÉ"), ["found"])
    }

    func testASearchWithoutWordsFindsNothing() throws {
        let search = try Self.search([("found", "alpha")])
        XCTAssertEqual(search.results(for: " "), [])
    }

    func testDataWithoutWordsIsRejected() throws {
        let url = try Self.write("found\t\n")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try EmojiSearch(contentsOf: url)) { error in
            XCTAssertEqual(error as? EmojiDataError, .invalidSearch(line: 1))
        }
    }

    private static func search(_ lines: [(emoji: String, words: String)]) throws -> EmojiSearch {
        let url = try write(lines.map { "\($0.emoji)\t\($0.words)" }.joined(separator: "\n"))
        defer { try? FileManager.default.removeItem(at: url) }
        return try EmojiSearch(contentsOf: url)
    }

    private static func write(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
