import XCTest
import KeyVoxParakeet
@testable import KeyVoxCore

@MainActor
final class ParakeetServiceTests: XCTestCase {
    func testStaleRequestCannotOverwriteCurrentTranscriptionState() {
        let service = ParakeetService()
        let staleRequestID = service.beginTranscriptionRequest()
        let currentRequestID = service.beginTranscriptionRequest()

        var staleCompletionCalled = false
        service.finishSuccessfulRequest(
            staleRequestID,
            finalText: "stale",
            likelyNoSpeech: false,
            detectedLanguageCode: "en"
        ) { _ in
            staleCompletionCalled = true
        }

        XCTAssertFalse(staleCompletionCalled)
        XCTAssertEqual(service.transcriptionText, "")
        XCTAssertFalse(service.lastResultWasLikelyNoSpeech)

        var currentCompletionText: String?
        service.finishSuccessfulRequest(
            currentRequestID,
            finalText: "current",
            likelyNoSpeech: false,
            detectedLanguageCode: "en"
        ) { result in
            currentCompletionText = result?.text
        }

        XCTAssertEqual(currentCompletionText, "current")
        XCTAssertEqual(service.transcriptionText, "current")
    }

    func testIsModelReadyIsFalseWhenResolverReturnsNil() {
        let service = ParakeetService()

        XCTAssertFalse(service.isModelReady)
    }

    func testTranscribeReturnsEmptyResultForEmptyFrames() {
        let service = ParakeetService()
        let expectation = expectation(description: "empty frames complete")

        service.transcribe(
            audioFrames: [],
            useDictionaryHintPrompt: true,
            enableAutoParagraphs: true
        ) { result in
            XCTAssertEqual(result?.text, "")
            XCTAssertTrue(service.lastResultWasLikelyNoSpeech)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testUpdateDictionaryHintPromptTrimsWhitespace() {
        let service = ParakeetService()

        service.updateDictionaryHintPrompt("  cueboard  ")

        XCTAssertEqual(service.dictionaryHintPrompt, "cueboard")
    }

    func testWarmupLoadsParakeetOffMainThread() throws {
        let modelURL = try makeModelDirectory()
        let expectation = expectation(description: "warmup loader invoked")
        let service = ParakeetService(
            modelURLResolver: { modelURL },
            parakeetLoader: { _, _ in
                XCTAssertFalse(Thread.isMainThread)
                expectation.fulfill()
                throw NSError(domain: "ParakeetServiceTests", code: 1)
            }
        )

        service.warmup()

        wait(for: [expectation], timeout: 1.0)
    }

    func testTranscribeFailsSafelyWithoutRuntimeBackend() throws {
        let modelURL = try makeModelFile()
        let service = ParakeetService(modelURLResolver: { modelURL })
        let expectation = expectation(description: "placeholder service fails safely")

        service.transcribe(
            audioFrames: [0.1, 0.2],
            useDictionaryHintPrompt: true,
            enableAutoParagraphs: true
        ) { result in
            XCTAssertNil(result)
            XCTAssertFalse(service.lastResultWasLikelyNoSpeech)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testIsLikelyNoSpeechRejectsShortLowConfidenceParakeetOutput() {
        let service = ParakeetService()
        let segments = [
            ParakeetSegment(
                startTime: 0,
                endTime: 550,
                text: "Yeah.",
                confidence: 0.603,
                noSpeechProbability: nil
            )
        ]

        XCTAssertTrue(
            service.isLikelyNoSpeech(
                transcribedSegments: segments,
                audioFrameCount: 8_799
            )
        )
    }

    func testIsLikelyNoSpeechKeepsHigherConfidenceShortSpeech() {
        let service = ParakeetService()
        let segments = [
            ParakeetSegment(
                startTime: 0,
                endTime: 480,
                text: "Yes.",
                confidence: 0.840,
                noSpeechProbability: nil
            )
        ]

        XCTAssertFalse(
            service.isLikelyNoSpeech(
                transcribedSegments: segments,
                audioFrameCount: 7_680
            )
        )
    }

    func testIsLikelyNoSpeechRejectsShortLowConfidenceSegmentWhenCaptureIncludesPadding() {
        let service = ParakeetService()
        let segments = [
            ParakeetSegment(
                startTime: 0,
                endTime: 550,
                text: "Yeah.",
                confidence: 0.591,
                noSpeechProbability: nil
            )
        ]

        XCTAssertTrue(
            service.isLikelyNoSpeech(
                transcribedSegments: segments,
                audioFrameCount: 18_847
            )
        )
    }

    func testIsLikelyNoSpeechKeepsShortLowConfidenceMultiwordSegment() {
        let service = ParakeetService()
        let segments = [
            ParakeetSegment(
                startTime: 0,
                endTime: 850,
                text: "Yeah, one two.",
                confidence: 0.745,
                noSpeechProbability: nil
            )
        ]

        XCTAssertFalse(
            service.isLikelyNoSpeech(
                transcribedSegments: segments,
                audioFrameCount: 19_701
            )
        )
    }

    func testIsLikelyNoSpeechKeepsSingleWordSpeechAboveFallbackThreshold() {
        let service = ParakeetService()
        let segments = [
            ParakeetSegment(
                startTime: 0,
                endTime: 1_000,
                text: "Lol.",
                confidence: 0.612,
                noSpeechProbability: nil
            )
        ]

        XCTAssertFalse(
            service.isLikelyNoSpeech(
                transcribedSegments: segments,
                audioFrameCount: 20_960
            )
        )
    }

    func testIsLikelyNoSpeechRejectsShortSingleWordNearThreshold() {
        let service = ParakeetService()
        let segments = [
            ParakeetSegment(
                startTime: 0,
                endTime: 470,
                text: "Yeah.",
                confidence: 0.616,
                noSpeechProbability: nil
            )
        ]

        XCTAssertTrue(
            service.isLikelyNoSpeech(
                transcribedSegments: segments,
                audioFrameCount: 22_437
            )
        )
    }

    func testIsLikelyNoSpeechRejectsLowConfidenceSingleWordLeak() {
        let service = ParakeetService()
        let segments = [
            ParakeetSegment(
                startTime: 0,
                endTime: 910,
                text: "Well,",
                confidence: 0.448,
                noSpeechProbability: 0
            )
        ]

        XCTAssertTrue(
            service.isLikelyNoSpeech(
                transcribedSegments: segments,
                audioFrameCount: 18_165
            )
        )
    }

    func testTrailingLikelyNoSpeechSegmentIsDroppedAfterValidSpeech() {
        let validSegment = ParakeetSegment(
            startTime: 0,
            endTime: 16_000,
            text: "This might have been exactly what we needed.",
            confidence: 0.980,
            noSpeechProbability: nil
        )
        let trailingSegment = ParakeetSegment(
            startTime: 16_050,
            endTime: 16_550,
            text: "Yeah.",
            confidence: 0.600,
            noSpeechProbability: nil
        )

        let filteredResult = ParakeetUtteranceGate.droppingLikelyNoSpeechTrailingSegments(
            from: ParakeetTranscriptionResult(
                segments: [validSegment, trailingSegment],
                detectedLanguageCode: "en",
                detectedLanguageName: "English"
            )
        )

        XCTAssertEqual(filteredResult.segments, [validSegment])
    }

    private func makeModelFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyvox-core-parakeet-\(UUID().uuidString).bin")
        try Data([0x01]).write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makeModelDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyvox-core-parakeet-dir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
