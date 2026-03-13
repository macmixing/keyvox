import Combine
import Foundation
import KeyVoxCore
import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSTranscriptionManagerTests {
    @Test func enableSessionFromInactiveStartsMonitoringAndArmsTimeout() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()

        #expect(harness.manager.isSessionActive == true)
        #expect(harness.manager.state == .idle)
        #expect(harness.recorder.enableMonitoringCallCount == 1)
        #expect(harness.manager.sessionExpirationDate != nil)
    }

    @Test func settingsBackedFiveMinuteTimingArmsFiveMinuteTimeout() async throws {
        let harness = try makeHarness(sessionDisableTiming: .fiveMinutes)
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()

        let expirationDate = try #require(harness.manager.sessionExpirationDate)
        let interval = expirationDate.timeIntervalSinceNow
        #expect(interval > 295)
        #expect(interval <= 300)
    }

    @Test func repeatedEnableSessionWhileActiveIsIgnored() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performEnableSessionCommand()

        #expect(harness.recorder.enableMonitoringCallCount == 1)
    }

    @Test func disableSessionWhileIdleStopsMonitoringImmediately() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performDisableSessionCommand()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.manager.sessionDisablePending == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
        #expect(harness.manager.sessionExpirationDate == nil)
    }

    @Test func disableSessionWhileRecordingFinishesThenDisables() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "hello world", languageCode: "en")

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performStartRecordingCommand()
        await harness.manager.performDisableSessionCommand()

        #expect(harness.manager.sessionDisablePending == true)
        #expect(harness.manager.isSessionActive == true)

        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.state == .idle)
        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func disableSessionWhileTranscribingFinishesThenDisables() async throws {
        let harness = try makeHarness(serviceShouldSuspend: true)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "test phrase", languageCode: "en")

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performStartRecordingCommand()
        let task = Task { await harness.manager.performStopRecordingCommand() }
        await Task.yield()
        await Task.yield()

        #expect(harness.manager.state == .transcribing)
        await harness.manager.performDisableSessionCommand()
        #expect(harness.manager.sessionDisablePending == true)

        harness.transcriptionService.resumeSuccess()
        await task.value
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func idleTimeoutDisablesActiveIdleSession() async throws {
        let harness = try makeHarness(sessionPolicy: iOSSessionPolicy(idleTimeout: 0.02))
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()
        try await Task.sleep(nanoseconds: 80_000_000)
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func idleTimeoutIsCancelledWhileRecordingAndRearmsAfterCompletion() async throws {
        let harness = try makeHarness(sessionPolicy: iOSSessionPolicy(idleTimeout: 0.03))
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "hello", languageCode: "en")

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performStartRecordingCommand()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(harness.manager.isSessionActive == true)
        #expect(harness.manager.state == .recording)

        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()
        try await Task.sleep(nanoseconds: 80_000_000)
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func enableSessionWithPermissionDeniedSurfacesError() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        harness.recorder.enableMonitoringError = iOSAudioRecorderError.microphonePermissionDenied

        await harness.manager.performEnableSessionCommand()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.manager.lastErrorMessage == "Microphone access is required to start recording.")
    }

    @Test func cancelCurrentUtteranceWhileRecordingDiscardsWithoutTranscribing() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performStartRecordingCommand()
        harness.recorder.currentCaptureDuration = 12
        harness.recorder.hasMeaningfulSpeechInCurrentCapture = true

        await harness.manager.performCancelCurrentUtterance()

        #expect(harness.manager.state == .idle)
        #expect(harness.recorder.cancelCurrentUtteranceCallCount == 1)
        #expect(harness.transcriptionService.transcribeCallCount == 0)
        #expect(harness.manager.isSessionActive == true)
    }

    @Test func cancelCurrentUtteranceWhileTranscribingCancelsAndReturnsToIdle() async throws {
        let harness = try makeHarness(serviceShouldSuspend: true)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "test phrase", languageCode: "en")

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performStartRecordingCommand()
        let task = Task { await harness.manager.performStopRecordingCommand() }
        await Task.yield()
        await Task.yield()

        #expect(harness.manager.state == .transcribing)
        await harness.manager.performCancelCurrentUtterance()

        #expect(harness.manager.state == .idle)
        #expect(harness.transcriptionService.cancelCallCount == 1)
        harness.transcriptionService.resumeSuccess()
        await task.value
    }

    @Test func abandonedRecordingCancellationKeepsSessionAlive() async throws {
        let harness = try makeHarness(sessionPolicy: iOSSessionPolicy(
            idleTimeout: 300,
            noSpeechAbandonmentTimeout: 0.02,
            postSpeechInactivityTimeout: 180,
            emergencyUtteranceCap: 900
        ))
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performStartRecordingCommand()
        harness.recorder.currentCaptureDuration = 0.03
        harness.recorder.hasMeaningfulSpeechInCurrentCapture = false

        try await Task.sleep(nanoseconds: 80_000_000)
        await settleAsyncManagerWork()

        #expect(harness.manager.state == .idle)
        #expect(harness.manager.isSessionActive == true)
        #expect(harness.recorder.cancelCurrentUtteranceCallCount == 1)
        #expect(harness.transcriptionService.transcribeCallCount == 0)
    }

    @Test func emergencyUtteranceCapCancelsUtteranceAndKeepsSessionAlive() async throws {
        let harness = try makeHarness(sessionPolicy: iOSSessionPolicy(
            idleTimeout: 300,
            noSpeechAbandonmentTimeout: 45,
            postSpeechInactivityTimeout: 180,
            emergencyUtteranceCap: 0.02
        ))
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performStartRecordingCommand()
        harness.recorder.currentCaptureDuration = 0.03
        harness.recorder.hasMeaningfulSpeechInCurrentCapture = true
        harness.recorder.timeSinceLastMeaningfulSpeech = 0.01

        try await Task.sleep(nanoseconds: 80_000_000)
        await settleAsyncManagerWork()

        #expect(harness.manager.state == .idle)
        #expect(harness.manager.isSessionActive == true)
        #expect(harness.recorder.cancelCurrentUtteranceCallCount == 1)
    }

    @Test func startFromIdleTransitionsToRecording() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performStartRecordingCommand()

        #expect(harness.manager.state == .recording)
        #expect(harness.recorder.startCallCount == 1)
    }

    @Test func repeatedStartWhileRecordingIsIgnored() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStartRecordingCommand()

        #expect(harness.manager.state == .recording)
        #expect(harness.recorder.startCallCount == 1)
    }

    @Test func stopWhileIdleIsNoOp() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performStopRecordingCommand()

        #expect(harness.manager.state == .idle)
        #expect(harness.recorder.stopCallCount == 0)
    }

    @Test func stopFromRecordingPublishesLastTranscriptionTextAndReturnsToIdle() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "hello world", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.state == .idle)
        #expect(harness.recorder.stopCallCount == 1)
        #expect(harness.manager.lastTranscriptionText == "Hello world")
        #expect(harness.manager.lastErrorMessage == nil)
    }

    @Test func stopFromRecordingRecordsSpokenWordsIntoWeeklyStatsStore() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "hello world again", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.weeklyWordStatsStore.combinedWordCount == 3)
        #expect(harness.weeklyWordStatsStore.snapshot.deviceWordCounts["test-device"] == 3)
    }

    @Test func stopFromRecordingWithCapsLockEnabledUppercasesFinalText() async throws {
        let harness = try makeHarness(capsLockEnabled: true)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "hello world", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.lastTranscriptionText == "HELLO WORLD")
    }

    @Test func stopSetsTranscribingWhileTranscriptionServiceIsInFlight() async throws {
        let harness = try makeHarness(serviceShouldSuspend: true)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "test phrase", languageCode: "en")

        await harness.manager.performStartRecordingCommand()

        let task = Task { await harness.manager.performStopRecordingCommand() }
        await Task.yield()
        await Task.yield()

        #expect(harness.manager.state == .transcribing)
        harness.transcriptionService.resumeSuccess()
        await task.value
        await waitForManagerState(harness.manager, toBe: .idle)
        #expect(harness.manager.state == .idle)
    }

    @Test func acceptedCaptureWithMissingModelSurfacesErrorAndSkipsTranscription() async throws {
        let harness = try makeHarness(modelPath: "")
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "should not run", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()

        #expect(harness.manager.state == .idle)
        #expect(harness.manager.isModelAvailable == false)
        #expect(harness.transcriptionService.transcribeCallCount == 0)
        #expect(harness.manager.lastTranscriptionText == nil)
        #expect(harness.manager.lastErrorMessage == "Whisper model not found in App Group container.")
    }

    @Test func likelyNoSpeechResultDoesNotPublishLastTranscriptionText() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "", languageCode: "en")
        harness.transcriptionService.lastResultWasLikelyNoSpeech = true

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.lastTranscriptionText == nil)
    }

    @Test func immediatelyDisablesSessionAfterSuccessfulTranscription() async throws {
        let harness = try makeHarness(sessionDisableTiming: .immediately)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "hello world", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func immediatelyDisablesSessionAfterEmptyOutput() async throws {
        let harness = try makeHarness(sessionDisableTiming: .immediately)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = emptyOutputCapture()

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func immediatelyDisablesSessionAfterMissingModel() async throws {
        let harness = try makeHarness(modelPath: "", sessionDisableTiming: .immediately)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func changingDisableTimingWhileActiveAndIdleRearmsTimeout() async throws {
        let harness = try makeHarness(sessionDisableTiming: .fiveMinutes)
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()
        let originalExpirationDate = try #require(harness.manager.sessionExpirationDate)

        harness.updateSessionDisableTiming(.oneHour)
        await settleAsyncManagerWork()

        let updatedExpirationDate = try #require(harness.manager.sessionExpirationDate)
        #expect(updatedExpirationDate.timeIntervalSince(originalExpirationDate) > 3_000)
    }

    @Test func changingDisableTimingToImmediatelyWhileActiveAndIdleShutsSessionDown() async throws {
        let harness = try makeHarness(sessionDisableTiming: .fiveMinutes)
        defer { harness.cleanup() }

        await harness.manager.performEnableSessionCommand()
        #expect(harness.manager.isSessionActive == true)

        harness.updateSessionDisableTiming(.immediately)
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func changingDisableTimingWhileRecordingAppliesAfterUtteranceCompletes() async throws {
        let harness = try makeHarness(sessionDisableTiming: .fiveMinutes)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "hello world", languageCode: "en")

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performStartRecordingCommand()

        harness.updateSessionDisableTiming(.immediately)
        await settleAsyncManagerWork()

        #expect(harness.manager.state == .recording)
        #expect(harness.manager.isSessionActive == true)
        #expect(harness.recorder.stopMonitoringCallCount == 0)

        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func repeatedStartWhileTranscribingIsIgnored() async throws {
        let harness = try makeHarness(serviceShouldSuspend: true)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "pending result", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        let task = Task { await harness.manager.performStopRecordingCommand() }
        await Task.yield()
        await Task.yield()

        #expect(harness.manager.state == .transcribing)
        await harness.manager.performStartRecordingCommand()
        #expect(harness.recorder.startCallCount == 1)

        harness.transcriptionService.resumeSuccess()
        await task.value
    }

    @Test func repeatedStopWhileTranscribingIsIgnored() async throws {
        let harness = try makeHarness(serviceShouldSuspend: true)
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "pending result", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        let task = Task { await harness.manager.performStopRecordingCommand() }
        await Task.yield()
        await Task.yield()

        #expect(harness.manager.state == .transcribing)
        await harness.manager.performStopRecordingCommand()
        #expect(harness.recorder.stopCallCount == 1)

        harness.transcriptionService.resumeSuccess()
        await task.value
    }

    @Test func emptyOutputFramesReturnToIdleWithoutTranscribing() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }
        harness.recorder.stoppedCapture = emptyOutputCapture()

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.state == .idle)
        #expect(harness.transcriptionService.transcribeCallCount == 0)
        #expect(harness.manager.lastTranscriptionText == nil)
    }

    @Test func dictionaryUpdatesRefreshHintPrompt() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        try harness.dictionaryStore.add(phrase: "cueit")
        await settleAsyncManagerWork()

        #expect(harness.transcriptionService.lastUpdatedPrompt?.lowercased().contains("cueit") == true)
    }

    private func makeHarness(
        modelPath: String? = nil,
        serviceShouldSuspend: Bool = false,
        capsLockEnabled: Bool = false,
        sessionDisableTiming: iOSSessionDisableTiming? = nil,
        sessionPolicy: iOSSessionPolicy = .default
    ) throws -> ManagerHarness {
        let tempRootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("iOSTranscriptionManagerTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRootURL, withIntermediateDirectories: true)
        let recorder = StubAudioRecorder()
        let transcriptionService = StubDictationService(shouldSuspend: serviceShouldSuspend)
        let dictionaryBase = tempRootURL.appendingPathComponent("Dictionary", isDirectory: true)
        let resolvedModelPath: String?
        if let modelPath {
            resolvedModelPath = modelPath.isEmpty ? nil : modelPath
        } else {
            let modelURL = tempRootURL.appendingPathComponent("stub-model.bin")
            try Data("stub-model".utf8).write(to: modelURL)
            resolvedModelPath = modelURL.path
        }
        let dictionaryStore = DictionaryStore(fileManager: .default, baseDirectoryURL: dictionaryBase)
        let postProcessor = TranscriptionPostProcessor()
        let keyboardBridge = KeyVoxKeyboardBridge()
        let defaultsSuiteName = "iOSTranscriptionManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let sessionDisableTimingSubject = sessionDisableTiming.map { timing in
            CurrentValueSubject<iOSSessionDisableTiming, Never>(timing)
        }
        let weeklyWordStatsStore = iOSWeeklyWordStatsStore(
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 0) },
            installationIDGenerator: { "test-device" }
        )
        let manager = iOSTranscriptionManager(
            recorder: recorder,
            transcriptionService: transcriptionService,
            dictionaryStore: dictionaryStore,
            weeklyWordStatsStore: weeklyWordStatsStore,
            postProcessor: postProcessor,
            keyboardBridge: keyboardBridge,
            modelPathProvider: { resolvedModelPath },
            capsLockEnabledProvider: { capsLockEnabled },
            sessionDisableTimingProvider: sessionDisableTimingSubject.map { subject in
                { subject.value }
            },
            sessionDisableTimingPublisher: sessionDisableTimingSubject?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher(),
            sessionPolicy: sessionPolicy
        )

        return ManagerHarness(
            manager: manager,
            recorder: recorder,
            transcriptionService: transcriptionService,
            dictionaryStore: dictionaryStore,
            weeklyWordStatsStore: weeklyWordStatsStore,
            sessionDisableTimingSubject: sessionDisableTimingSubject,
            tempRootURL: tempRootURL,
            defaultsSuiteName: defaultsSuiteName
        )
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

    private func rejectedCapture() -> iOSStoppedCapture {
        iOSStoppedCaptureProcessor.process(
            snapshot: Array(repeating: Float(0.00001), count: 4_000),
            captureDuration: 1.0,
            maxActiveSignalRunDuration: 0.1,
            gapRemovalRMSThreshold: 0.0023,
            lowConfidenceRMSCutoff: 0.0032,
            trueSilenceWindowRMSThreshold: 0.0018,
            normalizationTargetPeak: 0.9,
            normalizationMaxGain: 3.0
        )
    }

    private func emptyOutputCapture() -> iOSStoppedCapture {
        let classification = AudioCaptureClassifier.classify(
            snapshot: Array(repeating: Float(0.2), count: 4_000),
            speechOnly: [],
            captureDuration: 1.0,
            maxActiveSignalRunDuration: 0.1,
            lowConfidenceRMSCutoff: 0.0032,
            trueSilenceWindowRMSThreshold: 0.0018
        )

        return iOSStoppedCapture(
            snapshot: Array(repeating: Float(0.2), count: 4_000),
            outputFrames: [],
            classification: classification,
            captureDuration: 1.0,
            maxActiveSignalRunDuration: 0.1
        )
    }

    private func settleAsyncManagerWork() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }

    private func waitForManagerState(
        _ manager: iOSTranscriptionManager,
        toBe expectedState: iOSTranscriptionManager.State
    ) async {
        for _ in 0..<20 {
            if manager.state == expectedState {
                return
            }
            await Task.yield()
        }
    }
}

@MainActor
private final class ManagerHarness {
    let manager: iOSTranscriptionManager
    let recorder: StubAudioRecorder
    let transcriptionService: StubDictationService
    let dictionaryStore: DictionaryStore
    let weeklyWordStatsStore: iOSWeeklyWordStatsStore
    let sessionDisableTimingSubject: CurrentValueSubject<iOSSessionDisableTiming, Never>?
    let tempRootURL: URL
    let defaultsSuiteName: String

    init(
        manager: iOSTranscriptionManager,
        recorder: StubAudioRecorder,
        transcriptionService: StubDictationService,
        dictionaryStore: DictionaryStore,
        weeklyWordStatsStore: iOSWeeklyWordStatsStore,
        sessionDisableTimingSubject: CurrentValueSubject<iOSSessionDisableTiming, Never>?,
        tempRootURL: URL,
        defaultsSuiteName: String
    ) {
        self.manager = manager
        self.recorder = recorder
        self.transcriptionService = transcriptionService
        self.dictionaryStore = dictionaryStore
        self.weeklyWordStatsStore = weeklyWordStatsStore
        self.sessionDisableTimingSubject = sessionDisableTimingSubject
        self.tempRootURL = tempRootURL
        self.defaultsSuiteName = defaultsSuiteName
    }

    func updateSessionDisableTiming(_ timing: iOSSessionDisableTiming) {
        sessionDisableTimingSubject?.send(timing)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: tempRootURL)
        UserDefaults(suiteName: defaultsSuiteName)?.removePersistentDomain(forName: defaultsSuiteName)
    }
}

@MainActor
private final class StubAudioRecorder: iOSAudioRecording {
    var isRecording = false
    var isMonitoring = false
    var currentCaptureDeviceName = "iPhone Microphone"
    var currentCaptureDuration: TimeInterval = 0
    var hasMeaningfulSpeechInCurrentCapture = false
    var timeSinceLastMeaningfulSpeech: TimeInterval?
    var lastCaptureWasAbsoluteSilence = false
    var lastCaptureHadActiveSignal = true
    var lastCaptureWasLikelySilence = false
    var lastCaptureWasLongTrueSilence = false
    var lastCaptureDuration: TimeInterval = 1.0
    var maxActiveSignalRunDuration: TimeInterval = 0.5
    var startCallCount = 0
    var stopCallCount = 0
    var enableMonitoringCallCount = 0
    var ensureEngineRunningCallCount = 0
    var stopMonitoringCallCount = 0
    var cancelCurrentUtteranceCallCount = 0
    var startError: Error?
    var enableMonitoringError: Error?
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

    func enableMonitoring() async throws {
        enableMonitoringCallCount += 1
        if let enableMonitoringError {
            throw enableMonitoringError
        }
        isMonitoring = true
    }

    func startRecording() async throws {
        startCallCount += 1
        if let startError {
            throw startError
        }
        isMonitoring = true
        isRecording = true
        currentCaptureDuration = 0
        hasMeaningfulSpeechInCurrentCapture = false
        timeSinceLastMeaningfulSpeech = nil
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

    func ensureEngineRunning() throws {
        ensureEngineRunningCallCount += 1
        isMonitoring = true
    }

    func stopMonitoring() throws {
        stopMonitoringCallCount += 1
        isMonitoring = false
    }

    func cancelCurrentUtterance() {
        cancelCurrentUtteranceCallCount += 1
        isRecording = false
        currentCaptureDuration = 0
        hasMeaningfulSpeechInCurrentCapture = false
        timeSinceLastMeaningfulSpeech = nil
    }
}

@MainActor
private final class StubDictationService: iOSDictationService {
    private var continuation: CheckedContinuation<Void, Never>?
    private var pendingResume = false
    private let shouldSuspend: Bool

    var isTranscribing = false
    var lastResultWasLikelyNoSpeech = false
    var warmupCallCount = 0
    var cancelCallCount = 0
    var transcribeCallCount = 0
    var nextResult: TranscriptionProviderResult?
    var lastUpdatedPrompt: String?
    var lastUseDictionaryHintPrompt: Bool?
    var lastEnableAutoParagraphs: Bool?
    var lastAudioFrames: [Float] = []

    init(shouldSuspend: Bool = false) {
        self.shouldSuspend = shouldSuspend
    }

    func warmup() {
        warmupCallCount += 1
    }

    func cancelTranscription() {
        cancelCallCount += 1
    }

    func updateDictionaryHintPrompt(_ prompt: String) {
        lastUpdatedPrompt = prompt
    }

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        transcribeCallCount += 1
        lastAudioFrames = audioFrames
        lastUseDictionaryHintPrompt = useDictionaryHintPrompt
        lastEnableAutoParagraphs = enableAutoParagraphs

        let finish = {
            completion(self.nextResult)
        }

        if shouldSuspend {
            Task { @MainActor in
                await self.waitForResume()
                finish()
            }
        } else {
            finish()
        }
    }

    func resumeSuccess() {
        guard let continuation else {
            pendingResume = true
            return
        }

        self.continuation = nil
        pendingResume = false
        continuation.resume()
    }

    private func waitForResume() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if pendingResume {
                pendingResume = false
                continuation.resume()
                return
            }
            self.continuation = continuation
        }
    }
}
