import XCTest
@testable import KeyVoxPredictiveKeyboard

final class EnglishPredictiveEngineTests: XCTestCase {
    func testStandaloneLowercasePronounUsesGrammaticalCapitalization() {
        XCTAssertEqual(WordCasing.apply(of: "i", to: "i"), "I")
        XCTAssertEqual(WordCasing.apply(of: "it", to: "it"), "it")
        XCTAssertEqual(WordCasing.apply(of: "I", to: "I"), "I")
    }

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

    func testContextualDeletionCandidateSurvivesNativeCandidateExpansion() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "fo",
            previousWords: ["brown", "quick", "the"],
            touches: [],
            mode: .correction
        )

        XCTAssertTrue(
            response.suggestions.contains { $0.word == "fox" },
            "Observed suggestions: \(response.suggestions.map(\.word))"
        )
    }

    func testAdjacentSubstitutionRanksIntendedWordFirst() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "ocer",
            previousWords: ["jumps"],
            touches: [],
            mode: .correction
        )

        XCTAssertEqual(response.suggestions.first?.word, "over")
    }

    func testContractionRanksIntendedWordFirst() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "dnt",
            previousWords: ["please"],
            touches: [],
            mode: .correction
        )

        XCTAssertEqual(response.suggestions.first?.word, "don't")
    }

    func testSingleDeletionRanksIntendedWordFirst() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "ltters",
            previousWords: ["any"],
            touches: [],
            mode: .correction
        )

        XCTAssertEqual(response.suggestions.first?.word, "letters")
    }

    func testRankedSuggestionsAreUnique() throws {
        let engine = try EnglishPredictiveEngine()

        let response = try engine.predict(
            typedWord: "lettrrs",
            previousWords: ["any"],
            touches: [],
            mode: .correction
        )
        let normalizedWords = response.suggestions.map { $0.word.lowercased() }

        XCTAssertEqual(Set(normalizedWords).count, normalizedWords.count)
    }

    func testObservedAdjacentKeyErrorsRetainIntendedCandidate() throws {
        let engine = try EnglishPredictiveEngine()
        let cases: [(typed: String, previous: [String], expected: String)] = [
            ("jumls", ["fox"], "jumps"),
            ("pleaze", ["so"], "please"),
            ("plese", ["so"], "please"),
            ("layz", ["the"], "lazy"),
            ("jums", ["fox"], "jumps"),
            ("lont", ["a", "in", "wait"], "long"),
        ]

        for testCase in cases {
            let response = try engine.predict(
                typedWord: testCase.typed,
                previousWords: testCase.previous,
                touches: [],
                mode: .correction
            )
            XCTAssertTrue(
                response.suggestions.contains { $0.word == testCase.expected },
                "Missing \(testCase.expected) for \(testCase.typed): \(response.suggestions.map(\.word))"
            )
        }
    }
}
