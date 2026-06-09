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
        try accessor.copyFrame(
            at: targetFrameIndex,
            into: destination,
            usesCurrentArtifactLayout: false
        )

        let destinationPointer = destination.dataPointer.bindMemory(to: Float.self, capacity: destination.count)
        let destinationHiddenStride = destination.strides[1].intValue

        XCTAssertEqual(destinationPointer[0], 0)
        XCTAssertEqual(destinationPointer[1 * destinationHiddenStride], 1)
        XCTAssertEqual(destinationPointer[255 * destinationHiddenStride], 255)
        XCTAssertEqual(destinationPointer[1023 * destinationHiddenStride], 1023)
    }

    func testEncoderFrameAccessorCopiesFrameFromFloat16EncoderOutput() throws {
        let source = try MLMultiArray(
            shape: [1, 2, NSNumber(value: ParakeetCoreMLBackend.Constants.encoderChannelCount)],
            dataType: .float16
        )
        let destination = try MLMultiArray(
            shape: [1, NSNumber(value: ParakeetCoreMLBackend.Constants.encoderChannelCount), 1],
            dataType: .float32
        )

        let sourcePointer = source.dataPointer.bindMemory(to: UInt16.self, capacity: source.count)
        let timeStride = source.strides[1].intValue
        let hiddenStride = source.strides[2].intValue
        let targetFrameIndex = 1

        for hiddenIndex in 0..<ParakeetCoreMLBackend.Constants.encoderChannelCount {
            sourcePointer[(targetFrameIndex * timeStride) + (hiddenIndex * hiddenStride)] =
                ParakeetFloat16Storage.bitPattern(from: Float(hiddenIndex) / 10)
        }

        let accessor = try ParakeetCoreMLBackend.EncoderFrameAccessor(array: source, validFrameCount: 2)
        try accessor.copyFrame(
            at: targetFrameIndex,
            into: destination,
            usesCurrentArtifactLayout: true
        )

        let destinationPointer = destination.dataPointer.bindMemory(to: Float.self, capacity: destination.count)
        let destinationHiddenStride = destination.strides[1].intValue

        XCTAssertEqual(destinationPointer[0], 0, accuracy: 0.001)
        XCTAssertEqual(destinationPointer[1 * destinationHiddenStride], 0.1, accuracy: 0.001)
        XCTAssertEqual(destinationPointer[255 * destinationHiddenStride], 25.5, accuracy: 0.001)
        XCTAssertEqual(destinationPointer[639 * destinationHiddenStride], 63.9, accuracy: 0.05)
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

        let projectionPointer = projection.dataPointer.bindMemory(to: UInt16.self, capacity: projection.count)
        for hiddenIndex in 0..<ParakeetCoreMLBackend.Constants.decoderHiddenSize {
            projectionPointer[hiddenIndex] = ParakeetFloat16Storage.bitPattern(from: Float(hiddenIndex) / 10)
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

    func testCopyNormalizedDecoderProjectionRejectsZeroStride() throws {
        let projection = try MLMultiArray(
            shape: [1, 1, NSNumber(value: ParakeetCoreMLBackend.Constants.decoderHiddenSize)],
            dataType: .float32
        )
        let destination = try MLMultiArray(
            shape: [1, NSNumber(value: ParakeetCoreMLBackend.Constants.decoderHiddenSize), 1],
            dataType: .float32
        )

        XCTAssertThrowsError(
            try ParakeetCoreMLBackend.copyNormalizedDecoderProjection(
                projection,
                hiddenAxis: 2,
                into: destination,
                hiddenStride: 0
            )
        ) { error in
            XCTAssertEqual(
                error as? ParakeetError,
                .transcriptionFailed(code: -1, message: "invalid_decoder_stride")
            )
        }
    }

    func testCopyNormalizedDecoderStateSupportsHiddenMiddleLayout() throws {
        let state = try MLMultiArray(
            shape: [
                NSNumber(value: ParakeetCoreMLBackend.Constants.decoderLayerCount),
                NSNumber(value: ParakeetCoreMLBackend.Constants.decoderHiddenSize),
                1,
            ],
            dataType: .float16
        )
        let destination = try MLMultiArray(
            shape: [
                NSNumber(value: ParakeetCoreMLBackend.Constants.decoderLayerCount),
                1,
                NSNumber(value: ParakeetCoreMLBackend.Constants.decoderHiddenSize),
            ],
            dataType: .float32
        )

        let statePointer = state.dataPointer.bindMemory(to: UInt16.self, capacity: state.count)
        let stateStrides = state.strides.map(\.intValue)
        for layerIndex in 0..<ParakeetCoreMLBackend.Constants.decoderLayerCount {
            for hiddenIndex in 0..<ParakeetCoreMLBackend.Constants.decoderHiddenSize {
                let index = (layerIndex * stateStrides[0]) + (hiddenIndex * stateStrides[1])
                statePointer[index] = ParakeetFloat16Storage.bitPattern(
                    from: Float(layerIndex * 1000 + hiddenIndex) / 10
                )
            }
        }

        try ParakeetCoreMLBackend.copyNormalizedDecoderState(state, into: destination)

        let destinationPointer = destination.dataPointer.bindMemory(to: Float.self, capacity: destination.count)
        let destinationStrides = destination.strides.map(\.intValue)
        let firstLayerIndex = (0 * destinationStrides[0]) + (255 * destinationStrides[2])
        let secondLayerIndex = (1 * destinationStrides[0]) + (255 * destinationStrides[2])

        XCTAssertEqual(destinationPointer[firstLayerIndex], 25.5, accuracy: 0.001)
        XCTAssertEqual(destinationPointer[secondLayerIndex], 125.5, accuracy: 0.05)
    }

    func testCopyNormalizedDecoderStateSupportsLayerMiddleLayout() throws {
        let state = try MLMultiArray(
            shape: [
                1,
                NSNumber(value: ParakeetCoreMLBackend.Constants.decoderLayerCount),
                NSNumber(value: ParakeetCoreMLBackend.Constants.decoderHiddenSize),
            ],
            dataType: .float32
        )
        let destination = try MLMultiArray(
            shape: [
                NSNumber(value: ParakeetCoreMLBackend.Constants.decoderLayerCount),
                1,
                NSNumber(value: ParakeetCoreMLBackend.Constants.decoderHiddenSize),
            ],
            dataType: .float32
        )

        let statePointer = state.dataPointer.bindMemory(to: Float.self, capacity: state.count)
        let stateStrides = state.strides.map(\.intValue)
        for layerIndex in 0..<ParakeetCoreMLBackend.Constants.decoderLayerCount {
            for hiddenIndex in 0..<ParakeetCoreMLBackend.Constants.decoderHiddenSize {
                let index = (layerIndex * stateStrides[1]) + (hiddenIndex * stateStrides[2])
                statePointer[index] = Float(layerIndex * 1000 + hiddenIndex)
            }
        }

        try ParakeetCoreMLBackend.copyNormalizedDecoderState(state, into: destination)

        let destinationPointer = destination.dataPointer.bindMemory(to: Float.self, capacity: destination.count)
        let destinationStrides = destination.strides.map(\.intValue)
        let firstLayerIndex = (0 * destinationStrides[0]) + (255 * destinationStrides[2])
        let secondLayerIndex = (1 * destinationStrides[0]) + (255 * destinationStrides[2])

        XCTAssertEqual(destinationPointer[firstLayerIndex], 255)
        XCTAssertEqual(destinationPointer[secondLayerIndex], 1255)
    }

    func testFillFloatValuesSupportsFloat16Storage() throws {
        let array = try MLMultiArray(shape: [4], dataType: .float16)

        try ParakeetCoreMLBackend.fillFloatValues(in: array, with: [0.5, 1.5, 2.5, 3.5])

        let pointer = array.dataPointer.bindMemory(to: UInt16.self, capacity: array.count)
        XCTAssertEqual(ParakeetFloat16Storage.float(from: pointer[0]), 0.5, accuracy: 0.001)
        XCTAssertEqual(ParakeetFloat16Storage.float(from: pointer[1]), 1.5, accuracy: 0.001)
        XCTAssertEqual(ParakeetFloat16Storage.float(from: pointer[2]), 2.5, accuracy: 0.001)
        XCTAssertEqual(ParakeetFloat16Storage.float(from: pointer[3]), 3.5, accuracy: 0.001)
    }

    func testRelativeTextTimingIgnoresTrailingBlankTail() {
        let timing = ParakeetCoreMLBackend.relativeTextTiming(
            firstTextTimeIndex: 2,
            lastTextEndTimeIndex: 7,
            fallbackEndTimeIndex: 16,
            encoderFrameCount: 16,
            actualFrameCount: 20_730
        )

        XCTAssertEqual(timing.startMilliseconds, 161)
        XCTAssertEqual(timing.endMilliseconds, 566)
    }

    func testDecodeWindowsAddsTailContextForFinalRemainder() {
        let frameCount = 265_525
        let tailStartFrame = frameCount - ParakeetCoreMLBackend.Constants.chunkFrameCount
        let windows = ParakeetCoreMLBackend.decodeWindows(forFrameCount: frameCount)

        XCTAssertEqual(
            windows,
            [
                ParakeetCoreMLBackend.DecodeWindow(
                    startFrame: 0,
                    endFrame: ParakeetCoreMLBackend.Constants.chunkFrameCount,
                    usesTailContext: false
                ),
                ParakeetCoreMLBackend.DecodeWindow(
                    startFrame: ParakeetCoreMLBackend.Constants.chunkFrameCount,
                    endFrame: frameCount,
                    usesTailContext: false
                ),
                ParakeetCoreMLBackend.DecodeWindow(
                    startFrame: tailStartFrame,
                    endFrame: frameCount,
                    usesTailContext: true
                ),
            ]
        )
    }

    func testDecodeWindowsDoNotAddTailContextForExactChunkMultiple() {
        let windows = ParakeetCoreMLBackend.decodeWindows(forFrameCount: 480_000)

        XCTAssertEqual(
            windows,
            [
                ParakeetCoreMLBackend.DecodeWindow(
                    startFrame: 0,
                    endFrame: ParakeetCoreMLBackend.Constants.chunkFrameCount,
                    usesTailContext: false
                ),
                ParakeetCoreMLBackend.DecodeWindow(
                    startFrame: ParakeetCoreMLBackend.Constants.chunkFrameCount,
                    endFrame: 480_000,
                    usesTailContext: false
                ),
            ]
        )
    }

    func testMergedTokenIDsAppendOnlyNonOverlappingSuffix() {
        let merged = ParakeetCoreMLBackend.mergedTokenIDs(
            [10, 20, 30, 40],
            appending: [30, 40, 50, 60]
        )

        XCTAssertEqual(merged, [10, 20, 30, 40, 50, 60])
    }

    func testTailContextMergedTokensReplaceTimedOverlap() {
        let accumulated = [
            emittedToken(10, startFrame: 0, endFrame: 100),
            emittedToken(20, startFrame: 100, endFrame: 200),
            emittedToken(30, startFrame: 200, endFrame: 300),
            emittedToken(40, startFrame: 300, endFrame: 400),
        ]
        let rescue = [
            emittedToken(31, startFrame: 200, endFrame: 300),
            emittedToken(41, startFrame: 300, endFrame: 400),
            emittedToken(50, startFrame: 400, endFrame: 500),
        ]

        let merged = ParakeetCoreMLBackend.mergedTokens(
            accumulated,
            appending: rescue,
            usesTailContext: true
        )

        XCTAssertEqual(merged.map(\.tokenID), [10, 20, 31, 41, 50])
    }

    func testNonTailContextMergedTokensUseExactTokenOverlap() {
        let accumulated = [
            emittedToken(10, startFrame: 0, endFrame: 100),
            emittedToken(20, startFrame: 100, endFrame: 200),
            emittedToken(30, startFrame: 200, endFrame: 300),
        ]
        let next = [
            emittedToken(20, startFrame: 100, endFrame: 200),
            emittedToken(30, startFrame: 200, endFrame: 300),
            emittedToken(40, startFrame: 300, endFrame: 400),
        ]

        let merged = ParakeetCoreMLBackend.mergedTokens(
            accumulated,
            appending: next,
            usesTailContext: false
        )

        XCTAssertEqual(merged.map(\.tokenID), [10, 20, 30, 40])
    }

    func testUtteranceGateRejectsShortLowConfidenceResult() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 550,
                    text: "Yeah.",
                    confidence: 0.603,
                    noSpeechProbability: nil
                )
            ]
        )

        XCTAssertTrue(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 8_799))
    }

    func testUtteranceGateKeepsHigherConfidenceShortSpeech() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 480,
                    text: "Yes.",
                    confidence: 0.840,
                    noSpeechProbability: nil
                )
            ]
        )

        XCTAssertFalse(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 7_680))
    }

    func testUtteranceGateRejectsShortResultWhenDecoderSignalsNoSpeech() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 420,
                    text: "Yeah.",
                    confidence: 0.910,
                    noSpeechProbability: 0.780
                )
            ]
        )

        XCTAssertTrue(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 8_320))
    }

    func testUtteranceGateRejectsShortLowConfidenceResultWhenCaptureDurationIncludesPadding() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 550,
                    text: "Yeah.",
                    confidence: 0.591,
                    noSpeechProbability: nil
                )
            ]
        )

        XCTAssertTrue(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 18_847))
    }

    func testUtteranceGateKeepsShortLowConfidenceMultiwordSpeech() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 850,
                    text: "Yeah, one two.",
                    confidence: 0.745,
                    noSpeechProbability: nil
                )
            ]
        )

        XCTAssertFalse(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 19_701))
    }

    func testUtteranceGateKeepsSingleWordSpeechAboveFallbackThreshold() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 1_000,
                    text: "Lol.",
                    confidence: 0.612,
                    noSpeechProbability: nil
                )
            ]
        )

        XCTAssertFalse(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 20_960))
    }

    func testUtteranceGateRejectsShortSingleWordNearThreshold() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 470,
                    text: "Yeah.",
                    confidence: 0.616,
                    noSpeechProbability: nil
                )
            ]
        )

        XCTAssertTrue(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 22_437))
    }

    func testUtteranceGateRejectsLowConfidenceSingleWordLeak() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 910,
                    text: "Well,",
                    confidence: 0.448,
                    noSpeechProbability: 0
                )
            ]
        )

        XCTAssertTrue(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 18_165))
    }

    func testUtteranceGateKeepsShortResultWhenDecoderNoSpeechSignalIsLow() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 420,
                    text: "Yes.",
                    confidence: 0.910,
                    noSpeechProbability: 0.120
                )
            ]
        )

        XCTAssertFalse(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 8_320))
    }

    func testUtteranceGateKeepsLongerUtterance() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 1_400,
                    text: "This is longer.",
                    confidence: 0.612,
                    noSpeechProbability: nil
                )
            ]
        )

        XCTAssertFalse(ParakeetUtteranceGate.isLikelyNoSpeech(result: result, audioFrameCount: 22_400))
    }

    func testUtteranceGateDropsTrailingLikelyNoSpeechSegmentAfterValidSpeech() {
        let result = ParakeetTranscriptionResult(
            segments: [
                ParakeetSegment(
                    startTime: 0,
                    endTime: 16_000,
                    text: "This might have been exactly what we needed.",
                    confidence: 0.980,
                    noSpeechProbability: nil
                ),
                ParakeetSegment(
                    startTime: 16_050,
                    endTime: 16_550,
                    text: "Yeah.",
                    confidence: 0.600,
                    noSpeechProbability: nil
                )
            ]
        )

        let filteredResult = ParakeetUtteranceGate.droppingLikelyNoSpeechTrailingSegments(
            from: result
        )

        XCTAssertEqual(filteredResult.segments.count, 1)
        XCTAssertEqual(filteredResult.segments.first?.text, "This might have been exactly what we needed.")
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

    private func emittedToken(
        _ tokenID: Int32,
        startFrame: Int,
        endFrame: Int,
        confidence: Float = 1
    ) -> ParakeetCoreMLBackend.EmittedToken {
        ParakeetCoreMLBackend.EmittedToken(
            tokenID: tokenID,
            confidence: confidence,
            startFrame: startFrame,
            endFrame: endFrame
        )
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
