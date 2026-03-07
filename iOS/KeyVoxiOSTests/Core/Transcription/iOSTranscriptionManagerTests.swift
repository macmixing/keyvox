import Foundation
import KeyVoxCore
import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSTranscriptionManagerTests {
    @Test func startFromIdleTransitionsToRecording() async {
        let recorder = StubAudioRecorder()
        let writer = StubArtifactWriter()
        let manager = iOSTranscriptionManager(recorder: recorder, artifactWriter: writer)

        await manager.performStartRecordingCommand()

        #expect(manager.state == .recording)
        #expect(recorder.startCallCount == 1)
    }

    @Test func repeatedStartWhileRecordingIsIgnored() async {
        let recorder = StubAudioRecorder()
        let writer = StubArtifactWriter()
        let manager = iOSTranscriptionManager(recorder: recorder, artifactWriter: writer)

        await manager.performStartRecordingCommand()
        await manager.performStartRecordingCommand()

        #expect(manager.state == .recording)
        #expect(recorder.startCallCount == 1)
    }

    @Test func stopWhileIdleIsNoOp() async {
        let recorder = StubAudioRecorder()
        let writer = StubArtifactWriter()
        let manager = iOSTranscriptionManager(recorder: recorder, artifactWriter: writer)

        await manager.performStopRecordingCommand()

        #expect(manager.state == .idle)
        #expect(recorder.stopCallCount == 0)
    }

    @Test func stopFromRecordingWritesArtifactAndReturnsToIdle() async throws {
        let recorder = StubAudioRecorder()
        let writer = StubArtifactWriter()
        let manager = iOSTranscriptionManager(recorder: recorder, artifactWriter: writer)
        recorder.stoppedCapture = acceptedCapture()

        await manager.performStartRecordingCommand()
        await manager.performStopRecordingCommand()

        #expect(manager.state == .idle)
        #expect(recorder.stopCallCount == 1)
        #expect(manager.lastCaptureArtifact?.outputFrameCount == recorder.stoppedCapture.outputFrames.count)
        #expect(writer.lastRequest?.hadActiveSignal == true)
    }

    @Test func stopSetsProcessingCaptureWhileWriterIsInFlight() async throws {
        let recorder = StubAudioRecorder()
        let writer = StubArtifactWriter(shouldSuspend: true)
        let manager = iOSTranscriptionManager(recorder: recorder, artifactWriter: writer)
        recorder.stoppedCapture = acceptedCapture()

        await manager.performStartRecordingCommand()

        let task = Task { await manager.performStopRecordingCommand() }
        await Task.yield()

        #expect(manager.state == .processingCapture)
        writer.resumeSuccess()
        await task.value
        #expect(manager.state == .idle)
    }

    @Test func artifactWriterFailureSurfacesErrorAndReturnsToIdle() async {
        let recorder = StubAudioRecorder()
        let writer = StubArtifactWriter(error: TestError.writeFailed)
        let manager = iOSTranscriptionManager(recorder: recorder, artifactWriter: writer)
        recorder.stoppedCapture = acceptedCapture()

        await manager.performStartRecordingCommand()
        await manager.performStopRecordingCommand()

        #expect(manager.state == .idle)
        #expect(manager.lastErrorMessage == TestError.writeFailed.localizedDescription)
    }

    private func acceptedCapture() -> iOSStoppedCapture {
        iOSStoppedCaptureProcessor.process(
            snapshot: Array(repeating: Float(0.2), count: 4_000),
            captureDuration: 1.0,
            maxActiveSignalRunDuration: 0.5,
            gapRemovalRMSThreshold: 0.0023,
            lowConfidenceRMSCutoff: 0.0032,
            trueSilenceWindowRMSThreshold: 0.0018,
            normalizationTargetPeak: 0.9,
            normalizationMaxGain: 3.0
        )
    }
}

@MainActor
private final class StubAudioRecorder: iOSAudioRecording {
    var isRecording = false
    var currentCaptureDeviceName = "iPhone Microphone"
    var lastCaptureWasAbsoluteSilence = false
    var lastCaptureHadActiveSignal = true
    var lastCaptureWasLikelySilence = false
    var lastCaptureWasLongTrueSilence = false
    var lastCaptureDuration: TimeInterval = 1.0
    var maxActiveSignalRunDuration: TimeInterval = 0.5
    var startCallCount = 0
    var stopCallCount = 0
    var startError: Error?
    var stoppedCapture = iOSStoppedCaptureProcessor.process(
        snapshot: Array(repeating: Float(0.2), count: 4_000),
        captureDuration: 1.0,
        maxActiveSignalRunDuration: 0.5,
        gapRemovalRMSThreshold: 0.0023,
        lowConfidenceRMSCutoff: 0.0032,
        trueSilenceWindowRMSThreshold: 0.0018,
        normalizationTargetPeak: 0.9,
        normalizationMaxGain: 3.0
    )

    func startRecording() async throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
        isRecording = true
    }

    func stopRecording() async -> iOSStoppedCapture {
        stopCallCount += 1
        isRecording = false
        lastCaptureWasAbsoluteSilence = stoppedCapture.classification.isAbsoluteSilence
        lastCaptureHadActiveSignal = stoppedCapture.classification.hadActiveSignal
        lastCaptureWasLikelySilence = stoppedCapture.classification.shouldRejectLikelySilence
        lastCaptureWasLongTrueSilence = stoppedCapture.classification.isLongTrueSilence
        lastCaptureDuration = stoppedCapture.captureDuration
        maxActiveSignalRunDuration = stoppedCapture.maxActiveSignalRunDuration
        return stoppedCapture
    }
}

@MainActor
private final class StubArtifactWriter: Phase2CaptureArtifactWriting {
    private var continuation: CheckedContinuation<Void, Never>?
    private let error: Error?
    private let shouldSuspend: Bool

    var lastRequest: Phase2CaptureWriteRequest?

    init(error: Error? = nil, shouldSuspend: Bool = false) {
        self.error = error
        self.shouldSuspend = shouldSuspend
    }

    func writeLatestCapture(_ request: Phase2CaptureWriteRequest) async throws -> Phase2CaptureArtifact {
        lastRequest = request
        if shouldSuspend {
            await waitForResume()
        }
        if let error {
            throw error
        }
        return Phase2CaptureArtifact(
            capturedAt: request.capturedAt,
            sampleRate: request.sampleRate,
            snapshotFrameCount: request.snapshotFrames.count,
            outputFrameCount: request.outputFrames.count,
            captureDuration: request.captureDuration,
            hadActiveSignal: request.hadActiveSignal,
            wasAbsoluteSilence: request.wasAbsoluteSilence,
            wasLikelySilence: request.wasLikelySilence,
            wasLongTrueSilence: request.wasLongTrueSilence,
            maxActiveSignalRunDuration: request.maxActiveSignalRunDuration,
            currentCaptureDeviceName: request.currentCaptureDeviceName,
            snapshotWAVURL: URL(fileURLWithPath: "/tmp/latest-snapshot.wav"),
            transcriptionInputWAVURL: request.outputFrames.isEmpty ? nil : URL(fileURLWithPath: "/tmp/latest-transcription-input.wav"),
            metadataURL: URL(fileURLWithPath: "/tmp/latest-metadata.json")
        )
    }

    func resumeSuccess() {
        continuation?.resume()
        continuation = nil
    }

    private func waitForResume() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
        }
    }
}

private enum TestError: LocalizedError {
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed:
            return "write failed"
        }
    }
}
