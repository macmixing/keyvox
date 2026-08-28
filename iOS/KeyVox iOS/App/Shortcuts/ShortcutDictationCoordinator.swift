import Foundation

enum ShortcutDictationState: Equatable {
    case idle
    case recording
    case busy
}

enum ShortcutDictationOutcome: Equatable {
    case recordingStarted
    case transcriptionCompleted(String)
    case noSpeech
    case busy
    case failed(String)
}

@MainActor
protocol ShortcutDictationSessionControlling: AnyObject {
    var shortcutDictationState: ShortcutDictationState { get }
    var isSessionActive: Bool { get }
    var sessionDisablePending: Bool { get }

    func performStartRecordingCommand(isFromURL: Bool) async -> TranscriptionStartCommandResult
    func performStopRecordingCommand(releaseMicImmediately: Bool) async -> TranscriptionStopCommandResult
}

@MainActor
protocol ShortcutRecordingActivityCoordinating: AnyObject {
    func prepareForAudioRecordingIntent() async throws
    func completeAudioRecordingIntentStart(
        isSessionActive: Bool,
        sessionDisablePending: Bool
    ) async
}

extension TranscriptionManager: ShortcutDictationSessionControlling {
    var shortcutDictationState: ShortcutDictationState {
        switch state {
        case .idle:
            .idle
        case .recording:
            .recording
        case .processingCapture, .transcribing:
            .busy
        }
    }
}

extension KeyVoxSessionLiveActivityCoordinator: ShortcutRecordingActivityCoordinating {}

@MainActor
final class ShortcutDictationCoordinator {
    private let sessionController: any ShortcutDictationSessionControlling
    private let liveActivityCoordinator: any ShortcutRecordingActivityCoordinating

    init(
        sessionController: any ShortcutDictationSessionControlling,
        liveActivityCoordinator: any ShortcutRecordingActivityCoordinating
    ) {
        self.sessionController = sessionController
        self.liveActivityCoordinator = liveActivityCoordinator
    }

    func toggleRecording(releaseMicImmediately: Bool = false) async -> ShortcutDictationOutcome {
        switch sessionController.shortcutDictationState {
        case .idle:
            return await startRecording()
        case .recording:
            return await stopRecording(releaseMicImmediately: releaseMicImmediately)
        case .busy:
            return .busy
        }
    }

    private func startRecording() async -> ShortcutDictationOutcome {
        do {
            try await liveActivityCoordinator.prepareForAudioRecordingIntent()
        } catch {
            return .failed(error.localizedDescription)
        }

        let result = await sessionController.performStartRecordingCommand(isFromURL: false)
        await liveActivityCoordinator.completeAudioRecordingIntentStart(
            isSessionActive: sessionController.isSessionActive,
            sessionDisablePending: sessionController.sessionDisablePending
        )

        switch result {
        case .started:
            return .recordingStarted
        case .alreadyInProgress:
            return .busy
        case .failed(let message):
            return .failed(message)
        }
    }

    private func stopRecording(releaseMicImmediately: Bool) async -> ShortcutDictationOutcome {
        switch await sessionController.performStopRecordingCommand(
            releaseMicImmediately: releaseMicImmediately
        ) {
        case .completed(let text):
            return .transcriptionCompleted(text)
        case .noSpeech:
            return .noSpeech
        case .notRecording, .superseded:
            return .busy
        case .failed(let message):
            return .failed(message)
        }
    }
}
