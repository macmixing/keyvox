import XCTest
@testable import KeyVoxPredictiveKeyboard

final class EnglishRollingCorrectionPolicyTests: XCTestCase {
    func testUsesLaterSequenceEvidenceForSupportedRepairs() throws {
        let engine = try EnglishPredictiveEngine()
        let cases: [(words: [String], index: Int, expected: String)] = [
            (["me", "know", "if", "yoi", "have", "any", "questions"], 3, "you"),
            (["i", "have", "forwaeded", "to", "kelly"], 2, "forwarded"),
            (["or", "lets", "get", "creative"], 1, "let's"),
            (["i", "wasnt", "sure", "that"], 1, "wasn't"),
            (["thanks", "thats", "what", "i", "was"], 1, "that's"),
            (["why", "tat", "word"], 1, "that"),
        ]

        for testCase in cases {
            let selection = try rollingSelection(
                words: testCase.words,
                engine: engine
            )
            XCTAssertEqual(
                replacement(
                    at: testCase.index,
                    in: testCase.words,
                    selection: selection
                ),
                testCase.expected,
                "Failed context: \(testCase.words.joined(separator: " "))"
            )
        }
    }

    func testPreservesValidWordsAndNames() throws {
        let engine = try EnglishPredictiveEngine()
        let cases = [
            ["the", "form", "is", "here"],
            ["they", "were", "going", "home"],
            ["the", "wet", "paint", "is", "here"],
            ["get", "back", "to", "tim"],
            ["i", "think", "tim", "wants", "to", "move"],
            ["what", "did", "mark", "say"],
            ["next", "time", "ask", "jim", "to", "call", "me"],
        ]

        for words in cases {
            XCTAssertNil(
                try rollingSelection(words: words, engine: engine),
                "Unsafe context change: \(words.joined(separator: " "))"
            )
        }
    }

    func testAbstainsWhenContextAndSpellingDoNotAgree() throws {
        let engine = try EnglishPredictiveEngine()
        let cases = [
            ["last", "year", "reached", "nillion", "dollars"],
            ["hopefully", "ths", "can", "wait", "until"],
            ["i", "ljve", "you", "too"],
            ["okay", "i'll", "go", "fo", "a", "ticket"],
            ["the", "gaffer", "a", "dicision", "to", "make"],
            ["on", "the", "list", "kf", "possible"],
            ["have", "the", "files", "byt", "the", "th", "or"],
        ]

        for words in cases {
            XCTAssertNil(
                try rollingSelection(words: words, engine: engine),
                "Unsafe ambiguous change: \(words.joined(separator: " "))"
            )
        }
    }

    private func rollingSelection(
        words: [String],
        engine: EnglishPredictiveEngine
    ) throws -> RollingCorrectionSelection? {
        var tokens: [RollingCorrectionToken] = []
        for (index, word) in words.enumerated() {
            let previousWords = Array(words[..<index].suffix(3).reversed())
            let response = try engine.predict(
                typedWord: word,
                previousWords: previousWords,
                touches: [],
                mode: .correction
            )
            tokens.append(
                RollingCorrectionToken(
                    original: word,
                    correctionResponse: response,
                    protectsLiteral: false
                )
            )
        }
        return try EnglishRollingCorrectionPolicy.select(
            tokens: tokens,
            precedingWords: [],
            isProtectedWord: { _ in false },
            analyze: { try engine.analyze(word: $0, previousWords: $1) }
        )
    }

    private func replacement(
        at originalIndex: Int,
        in words: [String],
        selection: RollingCorrectionSelection?
    ) -> String? {
        guard let selection else { return nil }
        let windowOffset = max(0, words.count - selection.replacementWords.count)
        let replacementIndex = originalIndex - windowOffset
        guard selection.replacementWords.indices.contains(replacementIndex) else {
            return nil
        }
        return selection.replacementWords[replacementIndex]
    }
}
