import XCTest
@testable import KeyVoxLinguistics

final class CapitalizedSpellingsTests: XCTestCase {
    func testBundledListSpellsCapitalOnlyWords() throws {
        let spellings = try CapitalizedSpellings()

        XCTAssertEqual(spellings.spelling(of: "monday"), "Monday")
        XCTAssertEqual(spellings.spelling(of: "MONDAY"), "Monday")
        XCTAssertEqual(spellings.spelling(of: "iphone"), "iPhone")
        XCTAssertNil(spellings.spelling(of: "how"))
        XCTAssertNil(spellings.spelling(of: "will"))
    }

    func testWrittenOnlyRespellsLowercaseWords() throws {
        let spellings = try CapitalizedSpellings()

        XCTAssertEqual(spellings.written("monday"), "Monday")
        XCTAssertEqual(spellings.written("MONDAY"), "MONDAY")
        XCTAssertEqual(spellings.written("how"), "how")
    }
}
