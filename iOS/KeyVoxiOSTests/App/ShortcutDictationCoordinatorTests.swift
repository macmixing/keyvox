import Testing
@testable import KeyVox_iOS

@MainActor
struct ShortcutDictationCoordinatorTests {
    @Test func startsLiveActivityBeforeStartingSharedRecording() async {
        let calls = ShortcutDictationCallRecorder()
        let session = MockShortcutDictationSessionController(calls: calls)
        let activity = MockShortcutRecordingActivityCoordinator(calls: calls)
        let coordinator = ShortcutDictationCoordinator(
            sessionController: session,
            liveActivityCoordinator: activity
        )

        let outcome = await coordinator.toggleRecording()

        #expect(outcome == .recordingStarted)
        #expect(calls.values == ["prepareActivity", "startRecording", "completeActivity:true:false"])
    }

    @Test func rollsBackLiveActivityWhenSharedRecorderFailsToStart() async {
        let calls = ShortcutDictationCallRecorder()
        let session = MockShortcutDictationSessionController(
            calls: calls,
            startResult: .failed("Microphone unavailable")
        )
        let activity = MockShortcutRecordingActivityCoordinator(calls: calls)
        let coordinator = ShortcutDictationCoordinator(
            sessionController: session,
            liveActivityCoordinator: activity
        )

        let outcome = await coordinator.toggleRecording()

        #expect(outcome == .failed("Microphone unavailable"))
        #expect(calls.values == ["prepareActivity", "startRecording", "completeActivity:false:false"])
    }

    @Test func stopsRecordingStartedByAnotherSurfaceAndReturnsTranscript() async {
        let calls = ShortcutDictationCallRecorder()
        let session = MockShortcutDictationSessionController(
            calls: calls,
            state: .recording,
            stopResult: .completed("Shared transcription")
        )
        let activity = MockShortcutRecordingActivityCoordinator(calls: calls)
        let coordinator = ShortcutDictationCoordinator(
            sessionController: session,
            liveActivityCoordinator: activity
        )

        let outcome = await coordinator.toggleRecording(releaseMicImmediately: true)

        #expect(outcome == .transcriptionCompleted("Shared transcription"))
        #expect(calls.values == ["stopRecording:true"])
    }

    @Test func returnsNoSpeechWithoutProducingShortcutText() async {
        let calls = ShortcutDictationCallRecorder()
        let session = MockShortcutDictationSessionController(
            calls: calls,
            state: .recording,
            stopResult: .noSpeech
        )
        let coordinator = ShortcutDictationCoordinator(
            sessionController: session,
            liveActivityCoordinator: MockShortcutRecordingActivityCoordinator(calls: calls)
        )

        let outcome = await coordinator.toggleRecording()

        #expect(outcome == .noSpeech)
        #expect(calls.values == ["stopRecording:false"])
    }

    @Test func refusesAnotherToggleWhileSharedTranscriptionIsBusy() async {
        let calls = ShortcutDictationCallRecorder()
        let session = MockShortcutDictationSessionController(calls: calls, state: .busy)
        let coordinator = ShortcutDictationCoordinator(
            sessionController: session,
            liveActivityCoordinator: MockShortcutRecordingActivityCoordinator(calls: calls)
        )

        let outcome = await coordinator.toggleRecording()

        #expect(outcome == .busy)
        #expect(calls.values.isEmpty)
    }
}

@MainActor
private final class MockShortcutDictationSessionController: ShortcutDictationSessionControlling {
    private let calls: ShortcutDictationCallRecorder
    private let startResult: TranscriptionStartCommandResult
    private let stopResult: TranscriptionStopCommandResult

    var shortcutDictationState: ShortcutDictationState
    var isSessionActive = false
    var sessionDisablePending = false

    init(
        calls: ShortcutDictationCallRecorder,
        state: ShortcutDictationState = .idle,
        startResult: TranscriptionStartCommandResult = .started,
        stopResult: TranscriptionStopCommandResult = .noSpeech
    ) {
        self.calls = calls
        self.shortcutDictationState = state
        self.startResult = startResult
        self.stopResult = stopResult
    }

    func performStartRecordingCommand(isFromURL: Bool) async -> TranscriptionStartCommandResult {
        calls.values.append("startRecording")
        if startResult == .started {
            shortcutDictationState = .recording
            isSessionActive = true
        }
        return startResult
    }

    func performStopRecordingCommand(
        releaseMicImmediately: Bool
    ) async -> TranscriptionStopCommandResult {
        calls.values.append("stopRecording:\(releaseMicImmediately)")
        shortcutDictationState = .idle
        return stopResult
    }
}

@MainActor
private final class MockShortcutRecordingActivityCoordinator: ShortcutRecordingActivityCoordinating {
    private let calls: ShortcutDictationCallRecorder

    init(calls: ShortcutDictationCallRecorder) {
        self.calls = calls
    }

    func prepareForAudioRecordingIntent() async throws {
        calls.values.append("prepareActivity")
    }

    func completeAudioRecordingIntentStart(
        isSessionActive: Bool,
        sessionDisablePending: Bool
    ) async {
        calls.values.append("completeActivity:\(isSessionActive):\(sessionDisablePending)")
    }
}

@MainActor
private final class ShortcutDictationCallRecorder {
    var values: [String] = []
}
