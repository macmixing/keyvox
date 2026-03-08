import Foundation
import KeyVoxCore
import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSTranscriptionManagerTests {
    @Test func enableSessionFromInactiveStartsMonitoringAndArmsTimeout() async throws {
        let harness = try makeHarness()

        await harness.manager.performEnableSessionCommand()

        #expect(harness.manager.isSessionActive == true)
        #expect(harness.manager.state == .idle)
        #expect(harness.recorder.enableMonitoringCallCount == 1)
        #expect(harness.manager.sessionExpirationDate != nil)
    }

    @Test func repeatedEnableSessionWhileActiveIsIgnored() async throws {
        let harness = try makeHarness()

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performEnableSessionCommand()

        #expect(harness.recorder.enableMonitoringCallCount == 1)
    }

    @Test func disableSessionWhileIdleStopsMonitoringImmediately() async throws {
        let harness = try makeHarness()

        await harness.manager.performEnableSessionCommand()
        await harness.manager.performDisableSessionCommand()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.manager.sessionDisablePending == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
        #expect(harness.manager.sessionExpirationDate == nil)
    }

    @Test func disableSessionWhileRecordingFinishesThenDisables() async throws {
        let harness = try makeHarness()
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

        await harness.manager.performEnableSessionCommand()
        try await Task.sleep(nanoseconds: 80_000_000)
        await settleAsyncManagerWork()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.recorder.stopMonitoringCallCount == 1)
    }

    @Test func idleTimeoutIsCancelledWhileRecordingAndRearmsAfterCompletion() async throws {
        let harness = try makeHarness(sessionPolicy: iOSSessionPolicy(idleTimeout: 0.03))
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
        harness.recorder.enableMonitoringError = iOSAudioRecorderError.microphonePermissionDenied

        await harness.manager.performEnableSessionCommand()

        #expect(harness.manager.isSessionActive == false)
        #expect(harness.manager.lastErrorMessage == "Microphone access is required to start recording.")
    }

    @Test func cancelCurrentUtteranceWhileRecordingDiscardsWithoutTranscribing() async throws {
        let harness = try makeHarness()

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

        await harness.manager.performStartRecordingCommand()

        #expect(harness.manager.state == .recording)
        #expect(harness.recorder.startCallCount == 1)
    }

    @Test func repeatedStartWhileRecordingIsIgnored() async throws {
        let harness = try makeHarness()

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStartRecordingCommand()

        #expect(harness.manager.state == .recording)
        #expect(harness.recorder.startCallCount == 1)
    }

    @Test func stopWhileIdleIsNoOp() async throws {
        let harness = try makeHarness()

        await harness.manager.performStopRecordingCommand()

        #expect(harness.manager.state == .idle)
        #expect(harness.recorder.stopCallCount == 0)
    }

    @Test func stopFromRecordingPublishesTranscriptionSnapshotAndReturnsToIdle() async throws {
        let harness = try makeHarness()
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "hello world", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.state == .idle)
        #expect(harness.recorder.stopCallCount == 1)
        #expect(harness.manager.lastCaptureArtifact?.outputFrameCount == harness.recorder.stoppedCapture.outputFrames.count)
        #expect(harness.manager.lastTranscriptionSnapshot?.finalText == "Hello world")
        #expect(harness.manager.lastTranscriptionSnapshot?.usedDictionaryHintPrompt == false)
        #expect(harness.manager.lastErrorMessage == nil)
    }

    @Test func stopSetsProcessingCaptureWhileWriterIsInFlight() async throws {
        let harness = try makeHarness(writerShouldSuspend: true)
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "test", languageCode: "en")

        await harness.manager.performStartRecordingCommand()

        let task = Task { await harness.manager.performStopRecordingCommand() }
        await Task.yield()

        #expect(harness.manager.state == .processingCapture)
        harness.writer.resumeSuccess()
        await task.value
        #expect(harness.manager.state == .idle)
    }

    @Test func stopSetsTranscribingWhileTranscriptionServiceIsInFlight() async throws {
        let harness = try makeHarness(serviceShouldSuspend: true)
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
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "should not run", languageCode: "en")

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()

        #expect(harness.manager.state == .idle)
        #expect(harness.manager.isModelAvailable == false)
        #expect(harness.transcriptionService.transcribeCallCount == 0)
        #expect(harness.manager.lastTranscriptionSnapshot == nil)
        #expect(harness.manager.lastErrorMessage == "Whisper model not found in App Group container.")
    }

    @Test func likelyNoSpeechResultPublishesSuppressedSnapshot() async throws {
        let harness = try makeHarness()
        harness.recorder.stoppedCapture = acceptedCapture()
        harness.transcriptionService.nextResult = TranscriptionProviderResult(text: "", languageCode: "en")
        harness.transcriptionService.lastResultWasLikelyNoSpeech = true

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.lastTranscriptionSnapshot?.wasLikelyNoSpeech == true)
        #expect(harness.manager.lastTranscriptionSnapshot?.finalText == "")
    }

    @Test func repeatedStartWhileTranscribingIsIgnored() async throws {
        let harness = try makeHarness(serviceShouldSuspend: true)
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
        harness.recorder.stoppedCapture = emptyOutputCapture()

        await harness.manager.performStartRecordingCommand()
        await harness.manager.performStopRecordingCommand()
        await settleAsyncManagerWork()

        #expect(harness.manager.state == .idle)
        #expect(harness.transcriptionService.transcribeCallCount == 0)
        #expect(harness.manager.lastTranscriptionSnapshot == nil)
    }

    @Test func dictionaryUpdatesRefreshHintPrompt() async throws {
        let harness = try makeHarness()

        try harness.dictionaryStore.add(phrase: "cueit")
        await settleAsyncManagerWork()

        #expect(harness.transcriptionService.lastUpdatedPrompt?.lowercased().contains("cueit") == true)
    }

    private func makeHarness(
        modelPath: String? = nil,
        writerShouldSuspend: Bool = false,
        serviceShouldSuspend: Bool = false,
        sessionPolicy: iOSSessionPolicy = .default
    ) throws -> ManagerHarness {
        let recorder = StubAudioRecorder()
        let writer = StubArtifactWriter(shouldSuspend: writerShouldSuspend)
        let transcriptionService = StubDictationService(shouldSuspend: serviceShouldSuspend)
        let dictionaryBase = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let resolvedModelPath: String?
        if let modelPath {
            resolvedModelPath = modelPath.isEmpty ? nil : modelPath
        } else {
            let modelURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("bin")
            try Data("stub-model".utf8).write(to: modelURL)
            resolvedModelPath = modelURL.path
        }
        let dictionaryStore = DictionaryStore(fileManager: .default, baseDirectoryURL: dictionaryBase)
        let postProcessor = TranscriptionPostProcessor()
        let keyboardBridge = KeyVoxKeyboardBridge()
        let manager = iOSTranscriptionManager(
            recorder: recorder,
            artifactWriter: writer,
            transcriptionService: transcriptionService,
            dictionaryStore: dictionaryStore,
            postProcessor: postProcessor,
            keyboardBridge: keyboardBridge,
            modelPathProvider: { resolvedModelPath },
            sessionPolicy: sessionPolicy
        )

        return ManagerHarness(
            manager: manager,
            recorder: recorder,
            writer: writer,
            transcriptionService: transcriptionService,
            dictionaryStore: dictionaryStore
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
private struct ManagerHarness {
    let manager: iOSTranscriptionManager
    let recorder: StubAudioRecorder
    let writer: StubArtifactWriter
    let transcriptionService: StubDictationService
    let dictionaryStore: DictionaryStore
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
