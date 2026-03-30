import XCTest
import CoreML
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

    func testVocabularyPromptTokenIDsGreedyTokenizePromptText() throws {
        let modelDirectoryURL = try makeModelDirectory(
            vocabulary: [
                "0": "<|endoftext|>",
                "1": "<|startofcontext|>",
                "2": "D",
                "3": "oma",
                "4": "in",
                "5": " vo",
                "6": "ca",
                "7": "bu",
                "8": "lar",
                "9": "y",
                "10": ":",
                "11": " ex",
                "12": "amp",
                "13": "le",
                "14": ".",
                "15": "com",
                "16": ",",
                "17": " dom",
                "18": "te",
                "19": "ch",
            ]
        )
        let vocabulary = try ParakeetVocabulary(modelDirectoryURL: modelDirectoryURL)

        let tokenIDs = vocabulary.promptTokenIDs(from: "Domain vocabulary: example.com, dom.tech")

        XCTAssertEqual(tokenIDs, [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 14, 18, 19])
    }

    func testVocabularyPromptTokenIDsNormalizeWhitespaceBeforeTokenizing() throws {
        let modelDirectoryURL = try makeModelDirectory(
            vocabulary: [
                "0": "<|startofcontext|>",
                "1": "D",
                "2": "oma",
                "3": "in",
                "4": " vo",
                "5": "ca",
                "6": "bu",
                "7": "lar",
                "8": "y",
                "9": ":",
                "10": " ex",
                "11": "amp",
                "12": "le",
                "13": ".",
                "14": "com",
            ]
        )
        let vocabulary = try ParakeetVocabulary(modelDirectoryURL: modelDirectoryURL)

        let tokenIDs = vocabulary.promptTokenIDs(from: "  Domain   vocabulary:\nexample.com  ")

        XCTAssertEqual(tokenIDs, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14])
    }

    func testEncoderFrameAccessorCopiesFrameFromChannelMajorEncoderOutput() throws {
        let source = try MLMultiArray(
            shape: [1, NSNumber(value: ParakeetCoreMLBackend.Constants.encoderChannelCount), 3],
            dataType: .float32
        )
        let destination = try MLMultiArray(
            shape: [1, NSNumber(value: ParakeetCoreMLBackend.Constants.encoderChannelCount), 1],
            dataType: .float32
        )

        let sourcePointer = source.dataPointer.bindMemory(to: Float.self, capacity: source.count)
        let hiddenStride = source.strides[1].intValue
        let timeStride = source.strides[2].intValue
        let targetFrameIndex = 1

        for hiddenIndex in 0..<ParakeetCoreMLBackend.Constants.encoderChannelCount {
            sourcePointer[(hiddenIndex * hiddenStride) + (targetFrameIndex * timeStride)] = Float(hiddenIndex)
        }

        let accessor = try ParakeetCoreMLBackend.EncoderFrameAccessor(array: source, validFrameCount: 3)
        accessor.copyFrame(at: targetFrameIndex, into: destination)

        let destinationPointer = destination.dataPointer.bindMemory(to: Float.self, capacity: destination.count)
        let destinationHiddenStride = destination.strides[1].intValue

        XCTAssertEqual(destinationPointer[0], 0)
        XCTAssertEqual(destinationPointer[1 * destinationHiddenStride], 1)
        XCTAssertEqual(destinationPointer[255 * destinationHiddenStride], 255)
        XCTAssertEqual(destinationPointer[1023 * destinationHiddenStride], 1023)
    }

    func testCopyNormalizedDecoderProjectionSupportsFloat16AndFloat32() throws {
        let projection = try MLMultiArray(
            shape: [1, 1, NSNumber(value: ParakeetCoreMLBackend.Constants.decoderHiddenSize)],
            dataType: .float16
        )
        let destination = try MLMultiArray(
            shape: [1, NSNumber(value: ParakeetCoreMLBackend.Constants.decoderHiddenSize), 1],
            dataType: .float32
        )

        let projectionPointer = projection.dataPointer.bindMemory(to: Float16.self, capacity: projection.count)
        for hiddenIndex in 0..<ParakeetCoreMLBackend.Constants.decoderHiddenSize {
            projectionPointer[hiddenIndex] = Float16(Float(hiddenIndex) / 10)
        }

        try ParakeetCoreMLBackend.copyNormalizedDecoderProjection(
            projection,
            hiddenAxis: 2,
            into: destination
        )

        let destinationPointer = destination.dataPointer.bindMemory(to: Float.self, capacity: destination.count)
        let destinationStride = destination.strides[1].intValue

        XCTAssertEqual(destinationPointer[0], 0, accuracy: 0.001)
        XCTAssertEqual(destinationPointer[1 * destinationStride], 0.1, accuracy: 0.001)
        XCTAssertEqual(destinationPointer[255 * destinationStride], 25.5, accuracy: 0.001)
        XCTAssertEqual(destinationPointer[639 * destinationStride], 63.9, accuracy: 0.05)
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

    private func makeModelDirectory(vocabulary: [String: String]) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyvox-parakeet-vocab-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let vocabularyURL = directoryURL.appendingPathComponent("parakeet_vocab.json", isDirectory: false)
        let data = try JSONSerialization.data(withJSONObject: vocabulary, options: [.sortedKeys])
        try data.write(to: vocabularyURL)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        return directoryURL
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
