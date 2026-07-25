import XCTest
@testable import KeyVoxPredictiveKeyboard

final class EnglishPredictiveEngineTests: XCTestCase {
    func testMisspellingProducesRankedCandidates() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "teh",
            previousWords: ["saw"],
            touches: [],
            mode: .correction
        )

        XCTAssertFalse(response.suggestions.isEmpty)
        XCTAssertFalse(response.suggestions.contains { $0.word == "teh" })
        XCTAssertFalse(response.typedWordIsValid)
        XCTAssertGreaterThanOrEqual(response.automaticCorrectionProbability, 0)
        XCTAssertLessThanOrEqual(response.automaticCorrectionProbability, 1)
    }

    func testLexiconWordIsNeverActionable() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "emotion",
            previousWords: ["an"],
            touches: [],
            mode: .correction
        )

        XCTAssertTrue(response.typedWordIsValid)
        XCTAssertEqual(response.automaticCorrectionProbability, 0)
    }

    func testAccentOverlayDoesNotCreateAutomaticAction() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "cafe",
            previousWords: ["the"],
            touches: [],
            mode: .completion
        )

        let accentIndex = response.suggestions.firstIndex { $0.word == "café" }
        XCTAssertNotNil(accentIndex)
        XCTAssertLessThanOrEqual(accentIndex ?? .max, 1)
        XCTAssertEqual(response.automaticCorrectionProbability, 0)
    }

    func testNextWordUsesNativePredictionWithoutAutomaticAction() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "",
            previousWords: ["thank"],
            touches: [],
            mode: .nextWord
        )

        XCTAssertFalse(response.suggestions.isEmpty)
        XCTAssertEqual(response.automaticCorrectionProbability, 0)
    }

    func testInputBeyondNativeWordLimitRemainsUnactionable() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: String(repeating: "a", count: 80),
            previousWords: [],
            touches: [],
            mode: .correction
        )

        XCTAssertTrue(response.suggestions.isEmpty)
        XCTAssertTrue(response.typedWordIsValid)
        XCTAssertEqual(response.automaticCorrectionProbability, 0)
    }
}
