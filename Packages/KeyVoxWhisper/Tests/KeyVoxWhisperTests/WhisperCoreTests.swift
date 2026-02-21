import Foundation
import XCTest
import whisper
@testable import KeyVoxWhisper

final class WhisperCoreTests: XCTestCase {
    private static let dummyContext = OpaquePointer(bitPattern: 0x1)!

    func testWhisperErrorDescriptions() {
        XCTAssertEqual(WhisperError.initializationFailed.errorDescription, "Failed to initialize Whisper context")
        XCTAssertEqual(WhisperError.invalidFrames.errorDescription, "Audio frames are empty")
        XCTAssertEqual(
            WhisperError.transcriptionFailed(code: -3).errorDescription,
            "Whisper transcription failed with error code -3"
        )
    }

    func testTranscribeEmptyFramesThrowsInvalidFramesFirst() async {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).bin")
        let whisper = Whisper(fromFileURL: url)

        do {
            _ = try await whisper.transcribe(audioFrames: [])
            XCTFail("Expected invalidFrames error")
        } catch let error as WhisperError {
            XCTAssertEqual(error, .invalidFrames)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribeNonEmptyWithInvalidContextThrowsInitializationFailed() async {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).bin")
        let whisper = Whisper(fromFileURL: url)

        do {
            _ = try await whisper.transcribe(audioFrames: [0.1, 0.2, 0.3])
            XCTFail("Expected initializationFailed error")
        } catch let error as WhisperError {
            XCTAssertEqual(error, .initializationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSegmentInitialization() {
        let segment = Segment(startTime: 100, endTime: 220, text: "hello")
        XCTAssertEqual(segment.startTime, 100)
        XCTAssertEqual(segment.endTime, 220)
        XCTAssertEqual(segment.text, "hello")
    }

    func testTranscribePadsShortAudioAndBuildsSegments() async throws {
        let recorder = WhisperRuntimeRecorder(
            contextsToReturn: [Self.dummyContext],
            segments: [
                .init(text: nil, start: 2, end: 4, noSpeechProbability: 0.99),
                .init(text: "Hello world", start: 12, end: 15, noSpeechProbability: 0.18),
            ]
        )
        let whisper = makeWhisper(recorder: recorder, osMajorVersion: 14)
        let input: [Float] = [0.1, 0.2, 0.3]

        let segments = try await whisper.transcribe(audioFrames: input)

        XCTAssertEqual(recorder.capturedBuffers.count, 1)
        let submitted = try XCTUnwrap(recorder.capturedBuffers.first)
        XCTAssertEqual(submitted.count, 16_800)
        XCTAssertEqual(submitted[0], input[0], accuracy: 0.0001)
        XCTAssertEqual(submitted[1], input[1], accuracy: 0.0001)
        XCTAssertEqual(submitted[2], input[2], accuracy: 0.0001)
        XCTAssertEqual(submitted[3], 0, accuracy: 0.0001)
        XCTAssertEqual(submitted[16_799], 0, accuracy: 0.0001)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].text, "Hello world")
        XCTAssertEqual(segments[0].startTime, 120)
        XCTAssertEqual(segments[0].endTime, 150)
        XCTAssertEqual(segments[0].noSpeechProbability, 0.18, accuracy: 0.0001)
    }

    func testTranscribeDoesNotPadWhenInputAlreadyLongEnough() async throws {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [Self.dummyContext], segments: [])
        let whisper = makeWhisper(recorder: recorder, osMajorVersion: 14)
        let input = Array(repeating: Float(0.25), count: 16_820)

        let output = try await whisper.transcribe(audioFrames: input)

        XCTAssertTrue(output.isEmpty)
        XCTAssertEqual(recorder.capturedBuffers.count, 1)
        XCTAssertEqual(recorder.capturedBuffers[0].count, input.count)
        XCTAssertEqual(recorder.capturedBuffers[0][0], 0.25, accuracy: 0.0001)
        XCTAssertEqual(recorder.capturedBuffers[0][16_819], 0.25, accuracy: 0.0001)
    }

    func testTranscribeReturnsEmptyWhenWhisperReportsNoSegments() async throws {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [Self.dummyContext], segments: [])
        let whisper = makeWhisper(recorder: recorder, osMajorVersion: 14)

        let output = try await whisper.transcribe(audioFrames: [0.2, 0.2, 0.2, 0.2])

        XCTAssertTrue(output.isEmpty)
    }

    func testTranscribeThrowsFailureCodeWhenRuntimeStatusIsNonZero() async {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [Self.dummyContext], segments: [])
        recorder.fullStatus = -42
        let whisper = makeWhisper(recorder: recorder, osMajorVersion: 14)

        do {
            _ = try await whisper.transcribe(audioFrames: [0.1, 0.2, 0.3, 0.4])
            XCTFail("Expected transcriptionFailed")
        } catch let error as WhisperError {
            XCTAssertEqual(error, .transcriptionFailed(code: -42))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribeWithMetadataReturnsLanguageMetadata() async throws {
        let recorder = WhisperRuntimeRecorder(
            contextsToReturn: [Self.dummyContext],
            segments: [.init(text: "Hello", start: 0, end: 10, noSpeechProbability: 0.1)]
        )
        recorder.stubLangId = 42
        recorder.stubLangCode = "en"
        recorder.stubLangName = "english"

        let whisper = makeWhisper(recorder: recorder, osMajorVersion: 14)
        let result = try await whisper.transcribeWithMetadata(audioFrames: [0.1, 0.2])

        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.detectedLanguageCode, "en")
        XCTAssertEqual(result.detectedLanguageName, "english")
    }

    func testTranscribeWithMetadataReturnsNilMetadataWhenLangIdInvalid() async throws {
        let recorder = WhisperRuntimeRecorder(
            contextsToReturn: [Self.dummyContext],
            segments: [.init(text: "Hello", start: 0, end: 10, noSpeechProbability: 0.1)]
        )
        recorder.stubLangId = -1

        let whisper = makeWhisper(recorder: recorder, osMajorVersion: 14)
        let result = try await whisper.transcribeWithMetadata(audioFrames: [0.1, 0.2])

        XCTAssertEqual(result.segments.count, 1)
        XCTAssertNil(result.detectedLanguageCode)
        XCTAssertNil(result.detectedLanguageName)
    }

    func testVenturaRetriesContextCreationOnceWhenFirstAttemptFails() {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [nil, Self.dummyContext], segments: [])
        _ = makeWhisper(recorder: recorder, osMajorVersion: 13)

        XCTAssertEqual(recorder.contextParamsHistory.count, 2)
        XCTAssertTrue(recorder.contextParamsHistory.allSatisfy { !$0.use_gpu && !$0.flash_attn })
    }

    func testVenturaDoesNotRetryWhenFirstContextAttemptSucceeds() {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [Self.dummyContext, nil], segments: [])
        _ = makeWhisper(recorder: recorder, osMajorVersion: 13)

        XCTAssertEqual(recorder.contextParamsHistory.count, 1)
    }

    func testNonVenturaDoesNotRetryContextCreationWhenFirstAttemptFails() {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [nil, Self.dummyContext], segments: [])
        _ = makeWhisper(recorder: recorder, osMajorVersion: 14)

        XCTAssertEqual(recorder.contextParamsHistory.count, 1)
    }

    func testDeinitFreesContextWhenAvailable() {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [Self.dummyContext], segments: [])
        var whisper: Whisper? = makeWhisper(recorder: recorder, osMajorVersion: 14)
        XCTAssertTrue(recorder.freedContexts.isEmpty)

        whisper = nil
        XCTAssertNil(whisper)
        XCTAssertEqual(recorder.freedContexts.count, 1)
        XCTAssertEqual(recorder.freedContexts.first, Self.dummyContext)
    }

    func testDeinitSkipsFreeWhenContextIsMissing() {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [nil], segments: [])
        var whisper: Whisper? = makeWhisper(recorder: recorder, osMajorVersion: 14)

        whisper = nil
        XCTAssertNil(whisper)
        XCTAssertTrue(recorder.freedContexts.isEmpty)
    }

    func testTranscribeCancellationPreemptsValidation() async {
        let recorder = WhisperRuntimeRecorder(contextsToReturn: [nil], segments: [])
        let whisper = makeWhisper(recorder: recorder, osMajorVersion: 14)
        let gate = AsyncGate()

        let task = Task<Error?, Never> {
            await gate.wait()
            do {
                _ = try await whisper.transcribe(audioFrames: [])
                return nil
            } catch {
                return error
            }
        }

        task.cancel()
        await gate.open()

        let error = await task.value

        XCTAssertTrue(error is CancellationError)
    }

    private func makeWhisper(
        recorder: WhisperRuntimeRecorder,
        osMajorVersion: Int
    ) -> Whisper {
        Whisper(
            fromFileURL: URL(fileURLWithPath: "/tmp/keyvox-whisper-\(UUID().uuidString).bin"),
            withParams: .default,
            runtime: recorder.makeRuntime(),
            osVersionProvider: {
                OperatingSystemVersion(
                    majorVersion: osMajorVersion,
                    minorVersion: 0,
                    patchVersion: 0
                )
            },
            inferenceQueue: DispatchQueue(label: "KeyVoxWhisperTests.inference.\(UUID().uuidString)")
        )
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private final class WhisperRuntimeRecorder {
    struct StubSegment {
        let text: String?
        let start: Int64
        let end: Int64
        let noSpeechProbability: Float
    }

    var contextParamsHistory: [whisper_context_params] = []
    private var contextAttemptIndex = 0
    private var contextsToReturn: [OpaquePointer?]
    private var textPointers: [UnsafeMutablePointer<CChar>?]

    var fullStatus: Int32 = 0
    var capturedBuffers: [[Float]] = []
    var freedContexts: [OpaquePointer] = []
    var segments: [StubSegment]

    var stubLangId: Int32 = -1
    var stubLangCode: String?
    var stubLangName: String?
    private var langCodePointer: UnsafeMutablePointer<CChar>?
    private var langNamePointer: UnsafeMutablePointer<CChar>?

    init(contextsToReturn: [OpaquePointer?], segments: [StubSegment]) {
        self.contextsToReturn = contextsToReturn
        self.segments = segments
        self.textPointers = segments.map { segment in
            guard let text = segment.text else { return nil }
            return strdup(text)
        }
    }

    deinit {
        for pointer in textPointers {
            if let pointer {
                free(pointer)
            }
        }
        if let langCodePointer { free(langCodePointer) }
        if let langNamePointer { free(langNamePointer) }
    }

    func makeRuntime() -> WhisperRuntime {
        WhisperRuntime(
            contextDefaultParams: {
                whisper_context_default_params()
            },
            initFromFileWithParams: { [self] _, params in
                contextParamsHistory.append(params)
                defer { contextAttemptIndex += 1 }

                guard !contextsToReturn.isEmpty else { return nil }
                if contextAttemptIndex < contextsToReturn.count {
                    return contextsToReturn[contextAttemptIndex]
                }
                return contextsToReturn.last ?? nil
            },
            freeContext: { [self] context in
                freedContexts.append(context)
            },
            full: { [self] _, _, samples, sampleCount in
                if let samples {
                    let buffer = UnsafeBufferPointer(start: samples, count: Int(sampleCount))
                    capturedBuffers.append(Array(buffer))
                } else {
                    capturedBuffers.append([])
                }
                return fullStatus
            },
            fullNSegments: { [self] _ in
                Int32(segments.count)
            },
            fullGetSegmentText: { [self] _, index in
                guard index >= 0, Int(index) < textPointers.count else { return nil }
                guard let pointer = textPointers[Int(index)] else { return nil }
                return UnsafePointer(pointer)
            },
            fullGetSegmentT0: { [self] _, index in
                guard index >= 0, Int(index) < segments.count else { return 0 }
                return segments[Int(index)].start
            },
            fullGetSegmentT1: { [self] _, index in
                guard index >= 0, Int(index) < segments.count else { return 0 }
                return segments[Int(index)].end
            },
            fullGetSegmentNoSpeechProb: { [self] _, index in
                guard index >= 0, Int(index) < segments.count else { return 0 }
                return segments[Int(index)].noSpeechProbability
            },
            fullLangId: { [self] _ in
                stubLangId
            },
            langStr: { [self] id in
                guard id == stubLangId else { return nil }
                if let stubLangCode, langCodePointer == nil {
                    langCodePointer = strdup(stubLangCode)
                }
                return UnsafePointer(langCodePointer)
            },
            langStrFull: { [self] id in
                guard id == stubLangId else { return nil }
                if let stubLangName, langNamePointer == nil {
                    langNamePointer = strdup(stubLangName)
                }
                return UnsafePointer(langNamePointer)
            }
        )
    }
}
