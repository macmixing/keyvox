import XCTest
@testable import KeyVoxCore

final class WhisperServiceRetryHeuristicsTests: XCTestCase {
    func testTreatsThreeWordResultAsSuspiciousForLongChunk() {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 3, chunkSeconds: 23.85)

        XCTAssertTrue(suspicious)
    }

    func testDoesNotTreatThreeWordResultAsSuspiciousForShortChunk() {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 3, chunkSeconds: 2.0)

        XCTAssertFalse(suspicious)
    }

    func testDoesNotTreatNormalWordDensityAsSuspiciousOnLongChunk() {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 15, chunkSeconds: 20.0)

        XCTAssertFalse(suspicious)
    }

    func testRetriesEmptyResultForLongChunk() {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 0, chunkSeconds: 16.36)

        XCTAssertTrue(shouldRetry)
    }

    func testDoesNotRetryEmptyResultForShortChunk() {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 0, chunkSeconds: 2.5)

        XCTAssertFalse(shouldRetry)
    }

    func testDoesNotRetryNonEmptyResultAsEmptyChunk() {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 1, chunkSeconds: 16.36)

        XCTAssertFalse(shouldRetry)
    }
}
