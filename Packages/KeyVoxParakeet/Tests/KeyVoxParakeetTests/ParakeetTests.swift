import XCTest
@testable import KeyVoxParakeet

final class ParakeetTests: XCTestCase {
    func testInitThrowsWhenModelFileDoesNotExist() {
        let url = URL(fileURLWithPath: "/tmp/keyvox-parakeet-missing-\(UUID().uuidString).bin")

        XCTAssertThrowsError(try Parakeet(fromModelURL: url)) { error in
            XCTAssertEqual(error as? ParakeetError, .modelNotFound)
        }
    }

    func testTranscribeWithMetadataThrowsForEmptyFrames() throws {
        let url = try makeModelFile()
        let parakeet = try Parakeet(fromModelURL: url)

        let expectation = expectation(description: "throws invalid frames")
        Task {
            do {
                _ = try await parakeet.transcribeWithMetadata(audioFrames: [])
                XCTFail("Expected invalidFrames")
            } catch {
                XCTAssertEqual(error as? ParakeetError, .invalidFrames)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testTranscribeWithMetadataThrowsRuntimeUnavailableWithoutBackend() throws {
        let url = try makeModelFile()
        let parakeet = try Parakeet(fromModelURL: url)

        let expectation = expectation(description: "throws runtime unavailable")
        Task {
            do {
                _ = try await parakeet.transcribeWithMetadata(audioFrames: [0.1, 0.2])
                XCTFail("Expected runtimeUnavailable")
            } catch {
                XCTAssertEqual(error as? ParakeetError, .runtimeUnavailable)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testTranscribeMapsBackendResultToPublicStructs() throws {
        let url = try makeModelFile()
        let backend = MockParakeetRuntimeBackend()
        let expected = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 120,
                    text: "hello world",
                    confidence: 0.9,
                    noSpeechProbability: 0.1
                )
            ],
            detectedLanguageCode: "en",
            detectedLanguageName: "English"
        )
        backend.nextResult = expected
        let parakeet = try Parakeet(fromModelURL: url, backendFactory: { _ in backend })

        let expectation = expectation(description: "returns mapped result")
        Task {
            do {
                let result = try await parakeet.transcribeWithMetadata(audioFrames: [0.1, 0.2, 0.3])
                XCTAssertEqual(result, expected)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testCancellationThrowsCancelledAndDoesNotWedgeSubsequentCalls() throws {
        let url = try makeModelFile()
        let backend = MockParakeetRuntimeBackend(shouldSuspend: true)
        let parakeet = try Parakeet(fromModelURL: url, backendFactory: { _ in backend })
        let startedExpectation = expectation(description: "backend started")
        backend.onTranscribeStarted = {
            startedExpectation.fulfill()
        }

        let cancelledExpectation = expectation(description: "first call cancelled")
        Task {
            do {
                _ = try await parakeet.transcribeWithMetadata(audioFrames: [0.1, 0.2, 0.3])
                XCTFail("Expected cancellation")
            } catch {
                XCTAssertEqual(error as? ParakeetError, .cancelled)
            }
            cancelledExpectation.fulfill()
        }

        wait(for: [startedExpectation], timeout: 1.0)
        parakeet.cancelCurrentTranscription()
        backend.resume(
            with: ParakeetTranscriptionResult(
                segments: [ParakeetSegment(startTime: 0, endTime: 80, text: "ignored")]
            )
        )

        wait(for: [cancelledExpectation], timeout: 1.0)

        backend.shouldSuspend = false
        backend.nextResult = ParakeetTranscriptionResult(
            segments: [ParakeetSegment(startTime: 0, endTime: 100, text: "second pass")]
        )

        let secondExpectation = expectation(description: "second call succeeds")
        Task {
            do {
                let result = try await parakeet.transcribe(audioFrames: [0.1, 0.2])
                XCTAssertEqual(result.map(\.text), ["second pass"])
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            secondExpectation.fulfill()
        }

        wait(for: [secondExpectation], timeout: 1.0)
    }

    private func makeModelFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyvox-parakeet-\(UUID().uuidString).bin")
        try Data([0x00]).write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

private final class MockParakeetRuntimeBackend: ParakeetRuntimeBackend {
    var nextResult = ParakeetTranscriptionResult(segments: [])
    var shouldSuspend: Bool
    var onTranscribeStarted: (() -> Void)?
    private var continuation: CheckedContinuation<ParakeetTranscriptionResult, Error>?
    private var pendingResult: ParakeetTranscriptionResult?
    private var pendingError: Error?

    init(shouldSuspend: Bool = false) {
        self.shouldSuspend = shouldSuspend
    }

    func transcribe(audioFrames: [Float], params: ParakeetParams) async throws -> ParakeetTranscriptionResult {
        let onTranscribeStarted = onTranscribeStarted
        self.onTranscribeStarted = nil
        onTranscribeStarted?()
        if shouldSuspend {
            return try await withCheckedThrowingContinuation { continuation in
                if let pendingError {
                    self.pendingError = nil
                    continuation.resume(throwing: pendingError)
                    return
                }

                if let pendingResult {
                    self.pendingResult = nil
                    continuation.resume(returning: pendingResult)
                    return
                }

                self.continuation = continuation
            }
        }

        return nextResult
    }

    func cancelCurrentTranscription() {
        guard let continuation else {
            pendingError = ParakeetError.cancelled
            return
        }

        self.continuation = nil
        continuation.resume(throwing: ParakeetError.cancelled)
    }

    func unload() {}

    func resume(with result: ParakeetTranscriptionResult) {
        guard let continuation else {
            pendingResult = result
            return
        }

        self.continuation = nil
        continuation.resume(returning: result)
    }
}
