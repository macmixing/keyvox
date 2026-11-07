import XCTest
@testable import KeyVoxLinguistics

final class PerceptronPossessiveTaggingTests: XCTestCase {
    func testPossessiveWordsAreTaggedAsTheirBaseWord() {
        let word = String(UnicodeScalar(0x03B1)!) + String(UnicodeScalar(0x03B2)!)

        XCTAssertEqual(PerceptronLinguisticAnalyzer.taggingForm(of: word + "'s"), word)
        XCTAssertEqual(PerceptronLinguisticAnalyzer.taggingForm(of: word + "’s"), word)
        XCTAssertEqual(PerceptronLinguisticAnalyzer.taggingForm(of: word.uppercased() + "'S"), word.uppercased())
    }

    func testWordsWithoutAttachedPossessiveKeepTheirForm() {
        let word = String(UnicodeScalar(0x03B1)!) + String(UnicodeScalar(0x03B2)!)

        XCTAssertEqual(PerceptronLinguisticAnalyzer.taggingForm(of: word), word)
        XCTAssertEqual(PerceptronLinguisticAnalyzer.taggingForm(of: word + "s"), word + "s")
        XCTAssertEqual(PerceptronLinguisticAnalyzer.taggingForm(of: "'s"), "'s")
        XCTAssertEqual(PerceptronLinguisticAnalyzer.taggingForm(of: "1's"), "1's")
    }
}
