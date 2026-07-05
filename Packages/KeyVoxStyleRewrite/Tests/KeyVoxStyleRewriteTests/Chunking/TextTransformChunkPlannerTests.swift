import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class TextTransformChunkPlannerTests: XCTestCase {
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
        let planner = TextTransformChunkPlanner(tokenCounter: StyleRewriteTestWordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.promptOverheadTokenCount, 6)
        XCTAssertEqual(plan.maximumInputTokensPerChunk, 3)
        XCTAssertEqual(plan.chunks.map(\.text), ["one two three", "four five six", "seven eight"])
    }

    func testChunkPlannerAlsoHonorsMaximumResponseTokens() async throws {
        let request = TextTransformRequest(
            baseText: "one two three four five six seven eight nine ten",
            styleIdentifier: "test-style",
            instructions: "",
            promptPrefix: "",
            contextTokenLimit: 32_768,
            expectedOutputExpansionRatio: 1,
            safetyMarginTokens: 0,
            maximumResponseTokens: 19
        )
        let planner = TextTransformChunkPlanner(tokenCounter: StyleRewriteTestWordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.maximumInputTokensPerChunk, 3)
        XCTAssertEqual(plan.chunks.map(\.text), [
            "one two three",
            "four five six",
            "seven eight nine",
            "ten",
        ])
    }

    func testChunkPlannerPrefersSentenceBoundariesWithinBudget() async throws {
        let request = StyleRewriteTestRequestFactory.request("Alpha one. Beta two. Gamma three.")
        let planner = TextTransformChunkPlanner(tokenCounter: StyleRewriteTestWordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.chunks.map(\.text), ["Alpha one.", "Beta two.", "Gamma three."])
        XCTAssertEqual(plan.chunks.map(\.separatorAfter), [" ", " ", ""])
    }

    func testChunkPlannerSplitsLongSegmentByWordsWhenNeeded() async throws {
        let request = StyleRewriteTestRequestFactory.request("Alpha beta gamma delta")
        let planner = TextTransformChunkPlanner(tokenCounter: StyleRewriteTestWordTokenCounter())

        let plan = await planner.planChunks(for: request)

        XCTAssertEqual(plan.chunks.map(\.text), ["Alpha beta", "gamma delta"])
        XCTAssertEqual(plan.chunks.map(\.separatorAfter), [" ", ""])
    }
}
