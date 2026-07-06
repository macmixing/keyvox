import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class TextTransformCodableTests: XCTestCase {
    func testTextTransformRequestRoundTripsThroughJSON() throws {
        let request = TextTransformRequest(
            baseText: "base",
            styleIdentifier: "style",
            instructions: "instructions",
            promptPrefix: "prefix",
            promptSuffix: "suffix",
            contextTokenLimit: StyleRewriteDictationConfiguration.modelContextTokenLimit,
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

}
