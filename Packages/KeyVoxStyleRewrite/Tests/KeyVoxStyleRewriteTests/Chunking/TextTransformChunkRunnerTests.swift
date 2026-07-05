import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

@MainActor
final class TextTransformChunkRunnerTests: XCTestCase {
    func testChunkRunnerStitchesMultipleChunksInOrder() async throws {
        let request = StyleRewriteTestRequestFactory.request("Alpha one. Beta two.")
        let responder = StyleRewriteTestChunkResponder(responses: [
            0: "Styled alpha.",
            1: "Styled beta.",
        ])
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: StyleRewriteTestWordTokenCounter()),
            responder: responder
        )

        let result = await runner.transform(request)

        XCTAssertEqual(result.finalText, "Styled alpha. Styled beta.")
        XCTAssertEqual(result.chunkCount, 2)
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.errors, [])
    }

    func testChunkRunnerFallsBackOnlyFailedChunk() async throws {
        let request = StyleRewriteTestRequestFactory.request("Alpha one. Beta two.")
        let responder = StyleRewriteTestChunkResponder(
            responses: [0: "Styled alpha."],
            failingChunkIndexes: [1]
        )
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: StyleRewriteTestWordTokenCounter()),
            responder: responder
        )

        let result = await runner.transform(request)

        XCTAssertEqual(result.finalText, "Styled alpha. Beta two.")
        XCTAssertEqual(result.chunkCount, 2)
        XCTAssertTrue(result.applied)
        XCTAssertEqual(result.errors.map(\.chunkIndex), [1])
        XCTAssertEqual(result.chunkTimings.map(\.usedFallbackText), [false, true])
    }

    func testChunkRunnerTreatsOutputTruncationAsFallback() async throws {
        let request = StyleRewriteTestRequestFactory.request("Alpha one.")
        let responder = StyleRewriteTestChunkResponder(
            typedError: .outputTruncated("maximumTokenCount")
        )
        let runner = TextTransformChunkRunner(
            planner: TextTransformChunkPlanner(tokenCounter: StyleRewriteTestWordTokenCounter()),
            responder: responder
        )

        let result = await runner.transform(request)

        XCTAssertEqual(result.finalText, request.baseText)
        XCTAssertFalse(result.applied)
        XCTAssertEqual(result.errors.map(\.errorCode), [.localModelOutputTruncated])
    }
}
