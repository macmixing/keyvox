import XCTest
@testable import KeyVox

@MainActor
final class CustomVocabularyNormalizerTests: XCTestCase {
    private let normalizer = CustomVocabularyNormalizer()

    func testNormalizeReturnsEmptyForEmptyInput() {
        let output = normalizer.normalize("", with: [entry("alpha")])
        XCTAssertEqual(output, "")
    }

    func testNormalizeReturnsInputWhenNoUsableCandidates() {
        let output = normalizer.normalize("keep this text", with: [entry("!!!")])
        XCTAssertEqual(output, "keep this text")
    }

    func testNormalizeAppliesExactPhraseReplacementCaseInsensitively() {
        let output = normalizer.normalize(
            "I like new york in spring.",
            with: [entry("New York")]
        )
        XCTAssertEqual(output, "I like New York in spring.")
    }

    func testNormalizeHandlesDiacriticInsensitiveSingleWordMatching() {
        let output = normalizer.normalize("cafe", with: [entry("café")])
        XCTAssertEqual(output, "café")
    }

    func testNormalizeRejectsFuzzyMatchBelowThresholdForShortWords() {
        let output = normalizer.normalize("bata", with: [entry("beta")])
        XCTAssertEqual(output, "bata")
    }

    func testNormalizeAcceptsFuzzyMatchAboveThreshold() {
        let output = normalizer.normalize("camer ready", with: [entry("camera")])
        XCTAssertEqual(output, "camera ready")
    }

    func testNormalizeRejectsAmbiguousFuzzyCandidates() {
        let output = normalizer.normalize(
            "alphabet soup",
            with: [entry("alphxbet"), entry("alphqbet")]
        )
        XCTAssertEqual(output, "alphabet soup")
    }

    func testNormalizeAppliesMultipleTokenReplacementsDeterministically() {
        let output = normalizer.normalize(
            "camer readi camer",
            with: [entry("ready"), entry("camera")]
        )
        XCTAssertEqual(output, "camera ready camera")
    }

    private func entry(_ phrase: String) -> DictionaryEntry {
        DictionaryEntry(phrase: phrase)
    }
}
