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

    func testGermanListWritesNounsWithTheirCapitals() throws {
        let spellings = try CapitalizedSpellings(languageCode: "de")

        XCTAssertEqual(spellings.written("haus"), "Haus")
        XCTAssertEqual(spellings.written("mädchen"), "Mädchen")
        XCTAssertEqual(spellings.written("straße"), "Straße")
        XCTAssertEqual(spellings.written("berlin"), "Berlin")
        // Written in lowercase too, as a verb or another word, so left as typed.
        XCTAssertNil(spellings.spelling(of: "leben"))
        XCTAssertNil(spellings.spelling(of: "und"))
    }

    func testFrenchListSpellsNamesButNotDaysOrLanguageNames() throws {
        let spellings = try CapitalizedSpellings(languageCode: "fr")

        XCTAssertEqual(spellings.spelling(of: "paris"), "Paris")
        XCTAssertEqual(spellings.spelling(of: "écosse"), "Écosse")
        XCTAssertEqual(spellings.spelling(of: "ÉCOSSE"), "Écosse")
        XCTAssertEqual(spellings.spelling(of: "iphone"), "iPhone")
        // French writes days, months, and language names in lowercase.
        XCTAssertNil(spellings.spelling(of: "lundi"))
        XCTAssertNil(spellings.spelling(of: "janvier"))
        XCTAssertNil(spellings.spelling(of: "français"))
    }
}
