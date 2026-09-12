import Foundation
import XCTest
@testable import KeyVoxCore

final class SpelledOutNumberParserTests: XCTestCase {
    func testConsumesCompleteGeneratedNumberPhrases() throws {
        let locale = Locale.current
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .spellOut
        let parser = SpelledOutNumberParser(locale: locale)

        for value in [NSNumber(value: 42), NSNumber(value: -7), NSNumber(value: 1.25)] {
            let phrase = try XCTUnwrap(formatter.string(from: value))
            let parsed = try XCTUnwrap(parser.number(from: phrase))
            XCTAssertEqual(parsed.doubleValue, value.doubleValue)
        }
    }

    func testRejectsUnparsedSuffixAndEmptyInput() throws {
        let locale = Locale.current
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .spellOut
        let parser = SpelledOutNumberParser(locale: locale)
        let phrase = try XCTUnwrap(formatter.string(from: NSNumber(value: 42)))

        XCTAssertNil(parser.number(from: phrase + " " + UUID().uuidString))
        XCTAssertNil(parser.number(from: ""))
    }
}
