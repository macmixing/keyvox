import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

#if canImport(FoundationModels)
import FoundationModels
#endif

final class StyleRewriteFoundationTests: XCTestCase {
    func testNoneStyleReturnsNoRequest() {
        let request = StyleRewriteDictationConfiguration.request(
            for: .none,
            baseText: "Plain dictation."
        )

        XCTAssertNil(request)
    }

    func testPolishedRequestUsesFoundationTokenWindow() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note me and Sarah was talking."
        ))

        XCTAssertEqual(request.contextTokenLimit, 4_096)
        XCTAssertEqual(request.maximumResponseTokens, 512)
        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.polished.styleIdentifier)
        XCTAssertTrue(request.instructions.contains("Do not return options"))
        XCTAssertTrue(request.promptPrefix.contains("Return only the final rewritten text"))
    }

    func testChillRequestOnlyAsksFoundationForFillerCleanup() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "Hey what's up man?"
        ))

        XCTAssertTrue(request.instructions.contains("Remove only words like um, uh"))
        XCTAssertTrue(request.instructions.contains("Profanity is meaningful text, not filler."))
        XCTAssertTrue(request.instructions.contains("Preserve the speaker's wording, word order, casing, punctuation"))
        XCTAssertTrue(request.promptPrefix.contains("Keep profanity, insults, slang, emphasis words"))
        XCTAssertTrue(request.promptPrefix.contains("Preserve everything else, including wording, casing, and punctuation"))
    }

    func testCasualRequestUsesCleanupOnlyStyle() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "Hey what's up man?"
        ))

        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.casual.styleIdentifier)
        XCTAssertTrue(request.instructions.contains("You clean up casual dictated text."))
        XCTAssertTrue(request.instructions.contains("Preserve the speaker's wording, word order, casing, punctuation"))
        XCTAssertTrue(request.instructions.contains("Output: Hey, what's up man?"))
        XCTAssertTrue(request.instructions.contains("use normal sentence capitalization for that remaining first word"))
        XCTAssertTrue(request.promptPrefix.contains("Keep the original casing, punctuation, wording, tone, slang, and formality."))
        XCTAssertTrue(request.promptPrefix.contains("use normal sentence capitalization for that remaining first word"))
    }

    func testFoundationOutputPolicyFlagsMetaRefusal() {
        XCTAssertTrue(FoundationStyleRewriteOutputPolicy.isRefusalOrMetaResponse(
            "I cannot format the text you provided."
        ))
    }

    func testFoundationOutputPolicyAllowsOrdinaryCannotSentence() {
        XCTAssertFalse(FoundationStyleRewriteOutputPolicy.isRefusalOrMetaResponse(
            "i cannot believe this happened"
        ))
    }

    func testStyleFoundationRewriteEligibility() {
        XCTAssertFalse(StyleRewriteStyle.none.usesFoundationRewrite)
        XCTAssertTrue(StyleRewriteStyle.polished.usesFoundationRewrite)
        XCTAssertTrue(StyleRewriteStyle.casual.usesFoundationRewrite)
        XCTAssertTrue(StyleRewriteStyle.chill.usesFoundationRewrite)
    }

    func testPrewarmLifecycleIsIdempotentForMatchingRequest() throws {
        var lifecycle = FoundationStyleRewritePrewarmLifecycle()
        let key = FoundationStyleRewritePrewarmKey(
            styleIdentifier: StyleRewriteStyle.polished.styleIdentifier,
            instructions: "instructions",
            promptPrefix: "prefix"
        )

        XCTAssertTrue(lifecycle.shouldRequestPrewarm(for: key))
        lifecycle.markWarm()
        XCTAssertEqual(lifecycle.usage(for: key), .warm)
        XCTAssertFalse(lifecycle.shouldRequestPrewarm(for: key))
    }

    func testPrewarmLifecycleReleasesWarmSession() throws {
        var lifecycle = FoundationStyleRewritePrewarmLifecycle()
        let key = FoundationStyleRewritePrewarmKey(
            styleIdentifier: StyleRewriteStyle.polished.styleIdentifier,
            instructions: "instructions",
            promptPrefix: "prefix"
        )

        XCTAssertTrue(lifecycle.shouldRequestPrewarm(for: key))
        lifecycle.markWarm()
        XCTAssertTrue(lifecycle.release())
        XCTAssertEqual(lifecycle.usage(for: key), .cold)
        XCTAssertFalse(lifecycle.release())
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
        let output = ChillHeuristicFormatter().format("contact@dom.tech")

        XCTAssertEqual(output, "contact@dom.tech")
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

    func testFoundationRewriteRepairCollapsesAdjacentProtectedDuplicate() {
        let output = FoundationRewriteOutputRepair.repair(
            original: "im just trying trying to work",
            rewritten: "im just trying trying to work"
        )

        XCTAssertEqual(output.text, "im just trying to work")
        XCTAssertFalse(output.rejectedProtectedRemoval)
    }

    func testFoundationRewriteRepairRestoresLocalGapForProtectedRemoval() {
        let output = FoundationRewriteOutputRepair.repair(
            original: "im just having a working awesome day",
            rewritten: "im just having an awesome day"
        )

        XCTAssertEqual(output.text, "im just having a working awesome day")
        XCTAssertTrue(output.rejectedProtectedRemoval)
    }

    func testFoundationRewriteRepairRestoresOnlyProtectedTokensForDeletedGap() {
        let output = FoundationRewriteOutputRepair.repair(
            original: "Why can't you um fucking help me?",
            rewritten: "Why can't you help me?"
        )

        XCTAssertEqual(output.text, "Why can't you fucking help me?")
        XCTAssertTrue(output.rejectedProtectedRemoval)
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
            inferenceDuration: 0.5,
            textTransformationDuration: 0.25,
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(artifact)
        let decoded = try JSONDecoder().decode(DictationUtteranceArtifact.self, from: data)

        XCTAssertEqual(decoded, artifact)
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

    func testLiveFoundationTokenCounterUsesSystemCounter() async throws {
        try Self.requireLiveFoundationTests()

        #if canImport(FoundationModels)
        if #available(macOS 26.4, iOS 26.4, visionOS 26.4, *) {
            let tokenCount = try await FoundationTextTransformTokenCounter().tokenCount(
                for: "Quick note, please clean this dictated text."
            )
            XCTAssertGreaterThan(tokenCount, 0)
        } else {
            throw XCTSkip("FoundationModels token counting requires OS 26.4 or newer.")
        }
        #else
        throw XCTSkip("FoundationModels is unavailable in this SDK.")
        #endif
    }

    @MainActor
    func testLiveFoundationTransformerRunsChunkedRewrite() async throws {
        try Self.requireLiveFoundationTests()

        #if canImport(FoundationModels)
        guard #available(macOS 26.4, iOS 26.4, visionOS 26.4, *) else {
            throw XCTSkip("FoundationModels token counting requires OS 26.4 or newer.")
        }

        let baseText = Array(
            repeating: "quick note me and Sarah was talking this morning and she said the numbers look good but the last part needs cleanup before we send it to the client.",
            count: 8
        ).joined(separator: " ")
        let request = TextTransformRequest(
            baseText: baseText,
            styleIdentifier: "live-foundation-polished",
            instructions: """
            You are a copyeditor for dictated text.
            Return only one edited version of the input text.
            Preserve the original meaning and do not add commentary.
            """,
            promptPrefix: """
            Copyedit this dictated text.
            Return only the rewritten text.

            Text:

            """,
            contextTokenLimit: 170,
            expectedOutputExpansionRatio: 0.75,
            safetyMarginTokens: 24,
            maximumResponseTokens: 96
        )
        let transformer = FoundationStyleRewriteTextTransformer()

        let result = await transformer.transform(request)

        XCTAssertGreaterThan(result.chunkCount, 1)
        XCTAssertTrue(result.errors.isEmpty, result.errors.map(\.message).joined(separator: "; "))
        XCTAssertFalse(result.finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(result.applied)
        #else
        throw XCTSkip("FoundationModels is unavailable in this SDK.")
        #endif
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

    private static func requireLiveFoundationTests() throws {
        guard ProcessInfo.processInfo.environment["KEYVOX_RUN_FOUNDATION_MODEL_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Set KEYVOX_RUN_FOUNDATION_MODEL_LIVE_TESTS=1 to run live FoundationModels tests.")
        }
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

    init(responses: [Int: String], failingChunkIndexes: Set<Int> = []) {
        self.responses = responses
        self.failingChunkIndexes = failingChunkIndexes
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        if failingChunkIndexes.contains(chunk.index) {
            throw StubError.failed
        }
        return responses[chunk.index] ?? chunk.text
    }
}
