import Foundation
@testable import KeyVoxStyleRewrite

enum StyleRewriteTestRequestFactory {
    static func request(_ baseText: String) -> TextTransformRequest {
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

struct StyleRewriteTestWordTokenCounter: TextTransformTokenCounting {
    func tokenCount(for text: String) async throws -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

@MainActor
final class StyleRewriteTestChunkResponder: TextTransformChunkResponding {
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
