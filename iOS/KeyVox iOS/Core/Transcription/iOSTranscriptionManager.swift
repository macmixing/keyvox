import Combine
import Foundation

@MainActor
final class iOSTranscriptionManager: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case processingCapture
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCaptureArtifact: Phase2CaptureArtifact?
    @Published private(set) var lastErrorMessage: String?

    private let recorder: any iOSAudioRecording
    private let artifactWriter: any Phase2CaptureArtifactWriting

    init(
        recorder: any iOSAudioRecording,
        artifactWriter: any Phase2CaptureArtifactWriting
    ) {
        self.recorder = recorder
        self.artifactWriter = artifactWriter
    }

    convenience init(artifactWriter: any Phase2CaptureArtifactWriting) {
        self.init(recorder: iOSAudioRecorder(), artifactWriter: artifactWriter)
    }

    func handleStartRecordingCommand() {
        Task { await performStartRecordingCommand() }
    }

    func handleStopRecordingCommand() {
        Task { await performStopRecordingCommand() }
    }

    func performStartRecordingCommand() async {
        guard state == .idle else { return }
        state = .recording
        lastErrorMessage = nil

        do {
            try await recorder.startRecording()
        } catch {
            state = .idle
            lastErrorMessage = error.localizedDescription
        }
    }

    func performStopRecordingCommand() async {
        guard state == .recording else { return }
        state = .processingCapture

        let stoppedCapture = await recorder.stopRecording()
        let request = Phase2CaptureWriteRequest(
            capturedAt: Date(),
            sampleRate: 16000,
            snapshotFrames: stoppedCapture.snapshot,
            outputFrames: stoppedCapture.outputFrames,
            captureDuration: stoppedCapture.captureDuration,
            hadActiveSignal: recorder.lastCaptureHadActiveSignal,
            wasAbsoluteSilence: recorder.lastCaptureWasAbsoluteSilence,
            wasLikelySilence: recorder.lastCaptureWasLikelySilence,
            wasLongTrueSilence: recorder.lastCaptureWasLongTrueSilence,
            maxActiveSignalRunDuration: recorder.maxActiveSignalRunDuration,
            currentCaptureDeviceName: recorder.currentCaptureDeviceName
        )

        do {
            lastCaptureArtifact = try await artifactWriter.writeLatestCapture(request)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        state = .idle
    }
}
