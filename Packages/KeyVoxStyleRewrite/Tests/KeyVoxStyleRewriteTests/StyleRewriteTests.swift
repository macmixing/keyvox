import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class StyleRewriteTests: XCTestCase {
    func testNoneStyleReturnsNoRequest() {
        let request = StyleRewriteDictationConfiguration.request(
            for: .none,
            baseText: "Plain dictation."
        )

        XCTAssertNil(request)
    }

    func testPolishedRequestUsesModelTokenWindow() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note me and Sarah was talking."
        ))

        XCTAssertEqual(request.contextTokenLimit, 4_096)
        XCTAssertEqual(request.maximumResponseTokens, 512)
        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.polished.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.polishedLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testChillRequestUsesCleanupOnlyStyle() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "Hey what's up man?"
        ))

        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.chill.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.casualLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testCasualRequestUsesCleanupOnlyStyle() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "Hey what's up man?"
        ))

        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.casual.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.casualLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testStyleModelRewriteEligibility() {
        XCTAssertFalse(StyleRewriteStyle.none.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.polished.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.casual.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.chill.usesModelRewrite)
    }

    func testChillHeuristicFormatsSentenceSeparatorsWithoutEndingPeriod() {
        let output = ChillHeuristicFormatter().format(
            "Hey, this is really crazy. What are you doing tomorrow? I don't even know what I'm doing tonight, but I think this is cool."
        )

        XCTAssertEqual(
            output,
            "hey this is really crazy. what are you doing tomorrow? i dont even know what im doing tonight but i think this is cool"
        )
    }

    func testChillHeuristicKeepsFinalQuestionMark() {
        let output = ChillHeuristicFormatter().format("Hey what's up man?")

        XCTAssertEqual(output, "hey whats up man?")
    }

    func testChillHeuristicDoesNotOwnFillerRemoval() {
        let output = ChillHeuristicFormatter().format("Um hey uh this is cool.")

        XCTAssertEqual(output, "um hey uh this is cool")
    }

    func testChillHeuristicPreservesEmoji() {
        let output = ChillHeuristicFormatter().format(
            "KeyVox runs on-device and skips the subscription nonsense. 🎙️🔒"
        )

        XCTAssertEqual(
            output,
            "keyvox runs on device and skips the subscription nonsense. 🎙️🔒"
        )
    }

    func testChillHeuristicPreservesMathSymbols() {
        let output = ChillHeuristicFormatter().format("2+2=4")

        XCTAssertEqual(output, "2+2=4")
    }

    func testChillHeuristicPreservesEmailAddress() {
        let output = ChillHeuristicFormatter().format("dom@example.com")

        XCTAssertEqual(output, "dom@example.com")
    }

    func testChillHeuristicPreservesEmailAddressWithTrailingSentencePunctuation() {
        let output = ChillHeuristicFormatter().format("Email dom@example.com. Then wait.")

        XCTAssertEqual(output, "email dom@example.com. then wait")
    }

    func testChillHeuristicPreservesParagraphBreaks() {
        let output = ChillHeuristicFormatter().format(
            "Hey, this is really crazy.\n\nWhat are you doing tomorrow? I don't even know."
        )

        XCTAssertEqual(
            output,
            "hey this is really crazy\n\nwhat are you doing tomorrow? i dont even know"
        )
    }

    func testChillHeuristicPreservesOrderedListLineBreaks() {
        let output = ChillHeuristicFormatter().format(
            "I need to pick up a couple of things from the store.\n\n1. Apples\n2. Bananas"
        )

        XCTAssertEqual(
            output,
            "i need to pick up a couple of things from the store\n\n1. apples\n2. bananas"
        )
    }

    func testRewriteRepairRemovesCommaLeftByDeletedMiddleTokens() {
        let output = StyleRewriteOutputRepair.repairDeletedSeparatorPunctuation(
            original: "Hey, um what are you doing, um tomorrow?",
            rewritten: "Hey, what are you doing, tomorrow?"
        )

        XCTAssertEqual(output, "Hey, what are you doing tomorrow?")
    }

    func testRewriteRepairRestoresSentenceOpeningCommaAroundDeletedTokens() {
        let output = StyleRewriteOutputRepair.repairDeletedSeparatorPunctuation(
            original: "Phase three. Yo, um what are you doing?",
            rewritten: "Phase three. Yo what are you doing?"
        )

        XCTAssertEqual(output, "Phase three. Yo, what are you doing?")
    }

    func testChunkPlannerBudgetsInstructionsInputAndExpectedOutput() async throws {
        let request = TextTransformRequest(
            baseText: "one two three four five six seven eight",
            styleIdentifier: "test-style",
            instructions: "one two three four",
            promptPrefix: "five six",
            contextTokenLimit: 14,
            expectedOutputExpansionRatio: 1,
            safetyMarginTokens: 2
        )
        let planner = TextTransformChunkPlanner(tokenCounter: WordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.promptOverheadTokenCount, 6)
        XCTAssertEqual(plan.maximumInputTokensPerChunk, 3)
        XCTAssertEqual(plan.chunks.map(\.text), ["one two three", "four five six", "seven eight"])
    }

    func testChunkPlannerPrefersSentenceBoundariesWithinBudget() async throws {
        let request = Self.request("Alpha one. Beta two. Gamma three.")
        let planner = TextTransformChunkPlanner(tokenCounter: WordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.chunks.map(\.text), ["Alpha one.", "Beta two.", "Gamma three."])
        XCTAssertEqual(plan.chunks.map(\.separatorAfter), [" ", " ", ""])
    }

    func testChunkPlannerSplitsLongSegmentByWordsWhenNeeded() async throws {
        let request = Self.request("Alpha beta gamma delta")
        let planner = TextTransformChunkPlanner(tokenCounter: WordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.chunks.map(\.text), ["Alpha beta", "gamma delta"])
        XCTAssertEqual(plan.chunks.map(\.separatorAfter), [" ", ""])
    }

    @MainActor
    func testChunkRunnerStitchesMultipleChunksInOrder() async throws {
        let request = Self.request("Alpha one. Beta two.")
        let responder = StubChunkResponder(responses: [
            0: "Styled alpha.",
            1: "Styled beta.",
        ])
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: WordTokenCounter()),
            responder: responder
        )

        let result = await runner.transform(request)

        XCTAssertEqual(result.finalText, "Styled alpha. Styled beta.")
        XCTAssertEqual(result.chunkCount, 2)
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.errors, [])
    }

    @MainActor
    func testChunkRunnerFallsBackOnlyFailedChunk() async throws {
        let request = Self.request("Alpha one. Beta two.")
        let responder = StubChunkResponder(
            responses: [0: "Styled alpha."],
            failingChunkIndexes: [1]
        )
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: WordTokenCounter()),
            responder: responder
        )

        let result = await runner.transform(request)

        XCTAssertEqual(result.finalText, "Styled alpha. Beta two.")
        XCTAssertEqual(result.chunkCount, 2)
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.errors.map(\.chunkIndex), [1])
        XCTAssertEqual(result.chunkTimings.map(\.usedFallbackText), [false, true])
    }

    func testDictationUtteranceArtifactRoundTripsThroughJSON() throws {
        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: "raw",
            baseText: "base",
            selectedText: "styled",
            selectedStyleIdentifier: "test-style",
            variants: [
                DictationTextVariantArtifact(
                    styleIdentifier: "test-style",
                    text: "styled",
                    duration: 0.25,
                    chunkCount: 2,
                    applied: true,
                    errors: ["fallback"]
                )
            ],
            deterministicVariants: [
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: false,
                    listsEnabled: false,
                    text: "base"
                ),
                DictationDeterministicTextVariantArtifact(
                    paragraphsEnabled: true,
                    listsEnabled: true,
                    text: "base\n\nlisted"
                ),
            ],
            inferenceDuration: 0.5,
            textTransformationDuration: 0.25,
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(artifact)
        let decoded = try JSONDecoder().decode(DictationUtteranceArtifact.self, from: data)

        XCTAssertEqual(decoded, artifact)
    }

    func testDictationUtteranceArtifactDecodesMissingDeterministicVariantsAsEmpty() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "rawText": "raw",
          "baseText": "base",
          "selectedText": "styled",
          "selectedStyleIdentifier": "test-style",
          "variants": [],
          "inferenceDuration": 0.5,
          "textTransformationDuration": 0.25,
          "createdAt": 0
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(DictationUtteranceArtifact.self, from: data)

        XCTAssertEqual(decoded.deterministicVariants, [])
    }

    func testTextTransformRequestRoundTripsThroughJSON() throws {
        let request = TextTransformRequest(
            baseText: "base",
            styleIdentifier: "style",
            instructions: "instructions",
            promptPrefix: "prefix",
            promptSuffix: "suffix",
            contextTokenLimit: 4_096,
            expectedOutputExpansionRatio: 0.75,
            safetyMarginTokens: 384,
            maximumResponseTokens: 512
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(TextTransformRequest.self, from: data)

        XCTAssertEqual(decoded, request)
    }

    func testTextTransformResultRoundTripsThroughJSON() throws {
        let result = TextTransformResult(
            originalText: "base",
            finalText: "styled",
            styleIdentifier: "style",
            duration: 0.25,
            chunkCount: 1,
            applied: true,
            chunkTimings: [
                TextTransformChunkTiming(
                    chunkIndex: 0,
                    inputTokenCount: 8,
                    duration: 0.2,
                    usedFallbackText: false
                )
            ],
            errors: [
                TextTransformErrorSummary(chunkIndex: nil, message: "warning")
            ]
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TextTransformResult.self, from: data)

        XCTAssertEqual(decoded, result)
    }

    @MainActor
    func testStyleRewriteTransformerMapsBackendFailureWithoutClaimingVibeSuccess() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note this needs cleanup."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(failingChunkIndexes: [0])
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, request.baseText)
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.generationFailed])
    }

    @MainActor
    func testStyleRewriteTransformerMapsTypedLocalBackendFailure() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note this needs cleanup."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(typedError: .modelNotInstalled)
            }
        )

        let result = await transformer.transform(request)

        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.localModelNotInstalled])
    }

    @MainActor
    func testChillUsesHeuristicTextButDoesNotClaimFullVibeSuccessWhenCleanupFails() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "Um hey, this is cool."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: WordTokenCounter(),
            chunkResponderProvider: { _ in
                StubChunkResponder(typedError: .modelLoadFailed("missing"))
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "um hey this is cool")
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.localModelLoadFailed])
        XCTAssertEqual(result.processingMode, "local-model-cleanup-failed+heuristic")
    }

    private static func request(_ baseText: String) -> TextTransformRequest {
        TextTransformRequest(
            baseText: baseText,
            styleIdentifier: "test-style",
            instructions: "Instructions",
            promptPrefix: "Prompt:",
            contextTokenLimit: 6,
            expectedOutputExpansionRatio: 1,
            safetyMarginTokens: 0
        )
    }
}

private struct WordTokenCounter: TextTransformTokenCounting {
    func tokenCount(for text: String) async throws -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

@MainActor
private final class StubChunkResponder: TextTransformChunkResponding {
    enum StubError: Error {
        case failed
    }

    let responses: [Int: String]
    let failingChunkIndexes: Set<Int>
    let typedError: StyleRewriteBackendError?

    init(
        responses: [Int: String] = [:],
        failingChunkIndexes: Set<Int> = [],
        typedError: StyleRewriteBackendError? = nil
    ) {
        self.responses = responses
        self.failingChunkIndexes = failingChunkIndexes
        self.typedError = typedError
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        if let typedError {
            throw typedError
        }
        if failingChunkIndexes.contains(chunk.index) {
            throw StubError.failed
        }
        return responses[chunk.index] ?? chunk.text
    }
}
