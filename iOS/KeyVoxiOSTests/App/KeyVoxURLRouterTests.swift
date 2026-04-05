import Foundation
import KeyVoxCore
import KeyVoxTTS
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyVoxURLRouterTests {
    @Test func startRecordingRouteCanSkipReturnToHostPresentation() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let router = KeyVoxURLRouter(
            transcriptionManager: harness.manager,
            ttsManager: harness.ttsManager,
            audioModeCoordinator: harness.audioModeCoordinator
        )

        router.handle(route: .startRecording, shouldPresentReturnToHost: false)
        await settleAsyncWork()

        #expect(harness.manager.isReturnToHostViewPresented == false)
        #expect(harness.manager.state == .recording)
    }

    @Test func startRecordingRouteCanPresentReturnToHostWhenRequested() async throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let router = KeyVoxURLRouter(
            transcriptionManager: harness.manager,
            ttsManager: harness.ttsManager,
            audioModeCoordinator: harness.audioModeCoordinator
        )

        router.handle(route: .startRecording, shouldPresentReturnToHost: true)
        await settleAsyncWork()

        #expect(harness.manager.isReturnToHostViewPresented == true)
        #expect(harness.manager.state == .recording)
    }

    private func makeHarness() throws -> Harness {
        let tempRootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("KeyVoxURLRouterTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRootURL, withIntermediateDirectories: true)

        let defaultsSuiteName = "KeyVoxURLRouterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)

        let modelURL = tempRootURL.appendingPathComponent("stub-model.bin")
        try Data("stub-model".utf8).write(to: modelURL)

        let recorder = StubAudioRecorder()
        let transcriptionService = StubDictationService()
        let dictionaryStore = DictionaryStore(
            fileManager: .default,
            baseDirectoryURL: tempRootURL.appendingPathComponent("Dictionary", isDirectory: true)
        )
        let weeklyWordStatsStore = WeeklyWordStatsStore(
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 0) },
            installationIDGenerator: { "test-device" }
        )
        let settingsStore = AppSettingsStore(defaults: defaults)
        let manager = TranscriptionManager(
            recorder: recorder,
            transcriptionService: transcriptionService,
            dictionaryStore: dictionaryStore,
            weeklyWordStatsStore: weeklyWordStatsStore,
            postProcessor: TranscriptionPostProcessor(),
            keyboardBridge: KeyVoxKeyboardBridge(),
            interruptedCaptureRecoveryStore: InterruptedCaptureRecoveryStore(
                fileManager: .default,
                recoveryURLProvider: {
                    tempRootURL.appendingPathComponent("interrupted-capture.plist")
                }
            ),
            modelPathProvider: { modelURL.path }
        )
        let ttsManager = TTSManager(
            settingsStore: settingsStore,
            appHaptics: AppHaptics(),
            keyboardBridge: KeyVoxKeyboardBridge(),
            engine: StubTTSEngine(),
            playbackCoordinator: TTSPlaybackCoordinator()
        )
        let audioModeCoordinator = AudioModeCoordinator(
            transcriptionManager: manager,
            ttsManager: ttsManager,
            appTabRouter: AppTabRouter()
        )

        return Harness(
            manager: manager,
            ttsManager: ttsManager,
            audioModeCoordinator: audioModeCoordinator,
            tempRootURL: tempRootURL,
            defaultsSuiteName: defaultsSuiteName
        )
    }

    private func settleAsyncWork() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}

@MainActor
private final class Harness {
    let manager: TranscriptionManager
    let ttsManager: TTSManager
    let audioModeCoordinator: AudioModeCoordinator
    private let tempRootURL: URL
    private let defaultsSuiteName: String

    init(
        manager: TranscriptionManager,
        ttsManager: TTSManager,
        audioModeCoordinator: AudioModeCoordinator,
        tempRootURL: URL,
        defaultsSuiteName: String
    ) {
        self.manager = manager
        self.ttsManager = ttsManager
        self.audioModeCoordinator = audioModeCoordinator
        self.tempRootURL = tempRootURL
        self.defaultsSuiteName = defaultsSuiteName
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: tempRootURL)
        UserDefaults(suiteName: defaultsSuiteName)?.removePersistentDomain(forName: defaultsSuiteName)
    }
}

@MainActor
private final class StubAudioRecorder: AudioRecording {
    var isRecording = false
    var isMonitoring = false
    var currentCaptureDeviceName = "Test Microphone"
    var currentCaptureDuration: TimeInterval = 0
    var hasMeaningfulSpeechInCurrentCapture = false
    var timeSinceLastMeaningfulSpeech: TimeInterval?
    var lastCaptureWasAbsoluteSilence = false
    var lastCaptureHadActiveSignal = false
    var lastCaptureWasLikelySilence = false
    var lastCaptureWasLongTrueSilence = false
    var lastCaptureDuration: TimeInterval = 0
    var maxActiveSignalRunDuration: TimeInterval = 0

    func enableMonitoring() async throws {
        isMonitoring = true
    }

    func repairMonitoringAfterPlayback() async throws {
        isMonitoring = true
    }

    func startRecording() async throws {
        isMonitoring = true
        isRecording = true
    }

    func stopRecording() async -> StoppedCapture {
        isRecording = false
        return StoppedCaptureProcessor.process(
            snapshot: [],
            captureDuration: 0,
            maxActiveSignalRunDuration: 0,
            gapRemovalRMSThreshold: 0.0023,
            lowConfidenceRMSCutoff: 0.0032,
            trueSilenceWindowRMSThreshold: 0.0018,
            normalizationTargetPeak: 0.9,
            normalizationMaxGain: 3.0
        )
    }

    func ensureEngineRunning() throws {
        isMonitoring = true
    }

    func stopMonitoring() throws {
        isMonitoring = false
    }

    func cancelCurrentUtterance() {
        isRecording = false
    }
}

@MainActor
private final class StubDictationService: DictationProvider {
    var lastResultWasLikelyNoSpeech = false
    var isModelReady = true

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        completion(nil)
    }

    func warmup() {}

    func unloadModel() {}

    func cancelTranscription() {}

    func updateDictionaryHintPrompt(_ prompt: String) {}
}

private struct StubTTSEngine: TTSEngine {
    func prepareIfNeeded() async throws {}

    func prepareForForegroundSynthesis() async {}

    func prepareForBackgroundContinuation() async {}

    func makeAudioStream(
        for text: String,
        voiceID: String,
        fastModeEnabled: Bool
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
