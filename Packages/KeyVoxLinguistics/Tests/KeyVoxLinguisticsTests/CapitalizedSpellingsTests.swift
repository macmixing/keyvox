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

    func testEveryBundledListSpellsItsOwnWords() throws {
        for languageCode in ["en", "es"] {
            let url = try XCTUnwrap(KeyVoxLinguisticsResources.bundle.url(
                forResource: "capitalized_spellings_\(languageCode)",
                withExtension: "txt"
            ))
            let spellings = try CapitalizedSpellings(languageCode: languageCode)
            let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
            XCTAssertFalse(lines.isEmpty, languageCode)
            for line in lines {
                let fields = line.split(separator: "\t").map(String.init)
                XCTAssertEqual(spellings.spelling(of: fields[0]), fields[1], languageCode)
            }
        }
    }
}
