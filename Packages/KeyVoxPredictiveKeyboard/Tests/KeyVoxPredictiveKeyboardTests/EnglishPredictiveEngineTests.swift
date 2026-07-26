import XCTest
@testable import KeyVoxPredictiveKeyboard

final class EnglishPredictiveEngineTests: XCTestCase {
    func testStandaloneLowercasePronounUsesGrammaticalCapitalization() {
        XCTAssertEqual(
            EnglishAutomaticCorrectionPolicy.grammaticalReplacement(for: "i"),
            "I"
        )
        XCTAssertNil(EnglishAutomaticCorrectionPolicy.grammaticalReplacement(for: "it"))
        XCTAssertNil(EnglishAutomaticCorrectionPolicy.grammaticalReplacement(for: "I"))
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

    func testCorrectionPolicyAcceptsObservedHighConfidenceRepairs() throws {
        let engine = try EnglishPredictiveEngine()
        let cases: [(typed: String, previous: [String], expected: String)] = [
            ("lettrrs", ["any"], "letters"),
            ("dont", ["please"], "don't"),
            ("dnt", ["please"], "don't"),
            ("ocer", ["jumps"], "over"),
            ("ltters", ["any"], "letters"),
            ("jumls", ["fox"], "jumps"),
            ("pleaze", ["so"], "please"),
            ("plese", ["so"], "please"),
            ("layz", ["the"], "lazy"),
            ("jums", ["fox"], "jumps"),
        ]
        for testCase in cases {
            let response = try engine.predict(
                typedWord: testCase.typed,
                previousWords: testCase.previous,
                touches: [],
                mode: .correction
            )
            let selection = EnglishAutomaticCorrectionPolicy.select(
                typedWord: testCase.typed,
                response: response
            )
            XCTAssertEqual(
                selection.suggestion?.word,
                testCase.expected,
                "Failed input: \(testCase.typed)"
            )
        }
    }

    func testCorrectionPolicyUsesContextualTrailingInsertionRecovery() throws {
        let engine = try EnglishPredictiveEngine()
        let response = try engine.predict(
            typedWord: "fo",
            previousWords: ["brown", "quick", "the"],
            touches: [],
            mode: .correction
        )

        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: "fo",
            response: response
        )

        XCTAssertEqual(selection.suggestion?.word, "fox")
        XCTAssertEqual(selection.reason, .trailingInsertionRecovery)
    }

    func testCorrectionPolicyRecoversObservedTrailingLetterAtTypingConfidence() {
        let response = PredictionResponse(
            suggestions: [
                PredictiveSuggestion(
                    word: "bring",
                    nativeScore: -30_725,
                    nativeType: 268_435_457,
                    rankProbability: 0.91694
                ),
                PredictiveSuggestion(
                    word: "brings",
                    nativeScore: -104_199,
                    nativeType: 268_435_457,
                    rankProbability: 0.032166
                ),
            ],
            automaticCorrectionProbability: 0.8384,
            typedWordIsValid: false
        )

        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: "brin",
            response: response
        )

        XCTAssertEqual(selection.suggestion?.word, "bring")
        XCTAssertEqual(selection.reason, .trailingInsertionRecovery)
    }

    func testCorrectionPolicyRecoversObservedAdjacentRowSubstitution() {
        let response = PredictionResponse(
            suggestions: [
                PredictiveSuggestion(
                    word: "don't",
                    nativeScore: -26_167,
                    nativeType: 268_435_457,
                    rankProbability: 0.372648
                ),
                PredictiveSuggestion(
                    word: "long",
                    nativeScore: -469_068,
                    nativeType: 268_435_457,
                    rankProbability: 0.050191
                ),
                PredictiveSuggestion(
                    word: "lone",
                    nativeScore: -469_068,
                    nativeType: 268_435_457,
                    rankProbability: 0.018624
                ),
            ],
            automaticCorrectionProbability: 0.0812,
            typedWordIsValid: false
        )

        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: "lont",
            response: response
        )

        XCTAssertEqual(selection.suggestion?.word, "long")
        XCTAssertEqual(selection.reason, .substitutionRecovery)
    }

    func testCorrectionPolicyRecoversObservedMissingLetter() {
        let response = PredictionResponse(
            suggestions: [
                PredictiveSuggestion(
                    word: "lazy",
                    nativeScore: -80_970,
                    nativeType: 268_435_457,
                    rankProbability: 0.30083887200864157
                ),
                PredictiveSuggestion(
                    word: "lay",
                    nativeScore: -150_195,
                    nativeType: 268_435_457,
                    rankProbability: 0.012498046532128554
                ),
            ],
            automaticCorrectionProbability: 0.098100700944214386,
            typedWordIsValid: false
        )

        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: "lzy",
            response: response
        )

        XCTAssertEqual(selection.suggestion?.word, "lazy")
        XCTAssertEqual(selection.reason, .missingLetterRecovery)
    }

    func testCorrectionPolicyRejectsTrailingInsertionWithoutContextualSeparation() throws {
        let engine = try EnglishPredictiveEngine()
        let response = try engine.predict(
            typedWord: "fo",
            previousWords: [],
            touches: [],
            mode: .correction
        )

        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: "fo",
            response: response
        )

        XCTAssertNil(selection.suggestion)
    }

    func testCorrectionPolicyDoesNotInventTrailingLetterFromMissingLetterRule() {
        let response = PredictionResponse(
            suggestions: [
                PredictiveSuggestion(
                    word: "very",
                    nativeScore: 1,
                    nativeType: 1,
                    rankProbability: 0.43116704405415734
                ),
                PredictiveSuggestion(
                    word: "over",
                    nativeScore: 1,
                    nativeType: 1,
                    rankProbability: 0.008338666801763867
                ),
            ],
            automaticCorrectionProbability: 0.14694451984877344,
            typedWordIsValid: false
        )

        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: "ver",
            response: response
        )

        XCTAssertNil(selection.suggestion)
    }

    func testCorrectionPolicyRejectsSingleCharacterInput() {
        let response = PredictionResponse(
            suggestions: [
                PredictiveSuggestion(
                    word: "a",
                    nativeScore: 1,
                    nativeType: 1,
                    rankProbability: 1
                ),
            ],
            automaticCorrectionProbability: 1,
            typedWordIsValid: false
        )

        let selection = EnglishAutomaticCorrectionPolicy.select(
            typedWord: "q",
            response: response
        )

        XCTAssertNil(selection.suggestion)
        XCTAssertEqual(selection.reason, .insufficientInput)
    }

    func testCorrectionPolicyRejectsObservedAmbiguousInputs() throws {
        let engine = try EnglishPredictiveEngine()
        let cases: [(String, [String])] = [
            ("obe", ["jumps", "fox"]),
            ("lay", ["the", "obe"]),
        ]
        for (typedWord, previousWords) in cases {
            let response = try engine.predict(
                typedWord: typedWord,
                previousWords: previousWords,
                touches: [],
                mode: .correction
            )
            let selection = EnglishAutomaticCorrectionPolicy.select(
                typedWord: typedWord,
                response: response
            )
            XCTAssertNil(selection.suggestion, "Unsafe repair for input: \(typedWord)")
        }
    }
}
