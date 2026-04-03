import Combine
import Foundation
import UIKit

@MainActor
final class TTSManager: ObservableObject {
    private enum BackgroundPolicy {
        static let continuationGracePeriodNanoseconds: UInt64 = 12_000_000_000
    }

    enum PlaybackPreparationPhase: Equatable {
        case preparing
        case readyToReturn
    }

    @Published private(set) var state: KeyVoxTTSState = .idle
    @Published private(set) var lastErrorMessage: String?
    @Published var isPlaybackPreparationViewPresented = false
    @Published private(set) var playbackPreparationProgress: Double = 0
    @Published private(set) var playbackPreparationPhase: PlaybackPreparationPhase = .preparing

    private let settingsStore: AppSettingsStore
    private let keyboardBridge: KeyVoxKeyboardBridge
    private let engine: any TTSEngine
    private let playbackCoordinator: TTSPlaybackCoordinator
    private var activeRequest: KeyVoxTTSRequest?
    private var hasStartedPlaybackForActiveRequest = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTaskReleaseTask: Task<Void, Never>?

    var isActive: Bool {
        switch state {
        case .preparing, .generating, .playing:
            return true
        case .idle, .finished, .error:
            return false
        }
    }

    init(
        settingsStore: AppSettingsStore,
        keyboardBridge: KeyVoxKeyboardBridge,
        engine: any TTSEngine,
        playbackCoordinator: TTSPlaybackCoordinator
    ) {
        self.settingsStore = settingsStore
        self.keyboardBridge = keyboardBridge
        self.engine = engine
        self.playbackCoordinator = playbackCoordinator

        playbackCoordinator.onPlaybackStarted = { [weak self] in
            self?.handlePlaybackStarted()
        }
        playbackCoordinator.onPlaybackFinished = { [weak self] in
            self?.finishPlayback()
        }
        playbackCoordinator.onPlaybackCancelled = { [weak self] in
            self?.clearActiveRequest()
        }
        playbackCoordinator.onPlaybackFailed = { [weak self] error in
            self?.handleError(error.localizedDescription)
        }
        playbackCoordinator.onPlaybackMeterLevel = { [weak self] level in
            self?.keyboardBridge.publishPlaybackMeter(level: level)
        }
        playbackCoordinator.onPreparationProgress = { [weak self] bufferedSamples, requiredSamples, hasStartedPlayback in
            self?.updatePlaybackPreparationProgress(
                bufferedSamples: bufferedSamples,
                requiredSamples: requiredSamples,
                hasStartedPlayback: hasStartedPlayback
            )
        }
    }

    func handleAppDidBecomeActive() {
        KeyVoxIPCBridge.touchHeartbeat()
        Task {
            await engine.prepareForForegroundSynthesis()
        }
        playbackCoordinator.prepareForForegroundPlayback()
        endBackgroundTaskIfNeeded()
    }

    func handleAppWillResignActive() {
        guard isActive, hasStartedPlaybackForActiveRequest else { return }
        beginBackgroundTaskIfNeeded()
        Task {
            await engine.prepareForBackgroundContinuation()
        }
        playbackCoordinator.prepareForBackgroundTransition()
    }

    func handleAppDidEnterBackground() {
        dismissPlaybackPreparationView()
        beginBackgroundTaskIfNeeded()
        playbackCoordinator.didEnterBackground()
    }

    func startPlaybackFromClipboard() async {
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.isEmpty == false else {
            return
        }

        let request = KeyVoxTTSRequest(
            id: UUID(),
            text: text,
            createdAt: Date().timeIntervalSince1970,
            sourceSurface: .app,
            voiceID: settingsStore.ttsVoice.rawValue,
            kind: .speakClipboardText
        )
        KeyVoxIPCBridge.writeTTSRequest(request)
        await startPlayback(request, showPreparationView: false)
    }

    func startPlaybackFromPendingRequest() async {
        guard let request = KeyVoxIPCBridge.readTTSRequest(),
              request.trimmedText.isEmpty == false else {
            dismissPlaybackPreparationView()
            return
        }

        await startPlayback(request, showPreparationView: true)
    }

    func startPlayback(_ request: KeyVoxTTSRequest, showPreparationView: Bool = false) async {
        if isActive {
            await stopPlayback()
        }

        Self.log(
            "Starting request id=\(request.id.uuidString) voice=\(request.voiceID) source=\(request.sourceSurface.rawValue) textLength=\(request.trimmedText.count) showPreparationView=\(showPreparationView)"
        )
        activeRequest = request
        hasStartedPlaybackForActiveRequest = false
        lastErrorMessage = nil
        if showPreparationView {
            presentPlaybackPreparationView()
        } else {
            dismissPlaybackPreparationView()
        }
        beginBackgroundTaskIfNeeded()
        await engine.prepareForForegroundSynthesis()
        playbackCoordinator.prepareForForegroundPlayback()
        updateState(.preparing)

        do {
            try await engine.prepareIfNeeded()
            updateState(.generating)

            let stream = try await engine.makeAudioStream(
                for: request.trimmedText,
                voiceID: request.voiceID
            )
            playbackCoordinator.play(stream)
        } catch {
            handleError(error.localizedDescription)
        }
    }

    func stopPlayback() async {
        if let activeRequest {
            Self.log("Stop requested for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
        } else {
            Self.log("Stop requested with no active request.")
        }
        playbackCoordinator.stop()
        KeyVoxIPCBridge.clearTTSRequest()
        keyboardBridge.publishTTSStopped()
        clearActiveRequest()
    }

    private func finishPlayback() {
        if let activeRequest {
            Self.log("Playback finished for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
        } else {
            Self.log("Playback finished with no active request.")
        }
        keyboardBridge.publishTTSFinished()
        clearActiveRequest()
    }

    private func handleError(_ message: String) {
        if let activeRequest {
            Self.log("Playback failed for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID) error=\(message)")
        } else {
            Self.log("Playback failed with no active request. error=\(message)")
        }
        lastErrorMessage = message
        updateState(.error)
        keyboardBridge.publishTTSFailed(message: message)
        clearActiveRequest(clearPublishedState: false)
    }

    private func updateState(_ newState: KeyVoxTTSState) {
        state = newState

        switch newState {
        case .idle:
            KeyVoxIPCBridge.clearTTSState()
        case .preparing, .generating:
            keyboardBridge.publishTTSPreparing()
        case .playing:
            keyboardBridge.publishTTSPlaying()
        case .finished:
            keyboardBridge.publishTTSFinished()
        case .error:
            keyboardBridge.publishTTSFailed(message: lastErrorMessage)
        }
    }

    private func clearActiveRequest(clearPublishedState: Bool = true) {
        activeRequest = nil
        hasStartedPlaybackForActiveRequest = false
        KeyVoxIPCBridge.clearTTSRequest()
        dismissPlaybackPreparationView()
        endBackgroundTaskIfNeeded()

        if clearPublishedState {
            state = .idle
            KeyVoxIPCBridge.clearTTSState()
        }
    }

    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        guard isActive else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "KeyVoxTTSPlayback") { [weak self] in
            Task { @MainActor [weak self] in
                self?.endBackgroundTaskIfNeeded()
            }
        }
        scheduleBackgroundTaskRelease()
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        backgroundTaskReleaseTask?.cancel()
        backgroundTaskReleaseTask = nil
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func scheduleBackgroundTaskRelease() {
        backgroundTaskReleaseTask?.cancel()
        backgroundTaskReleaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: BackgroundPolicy.continuationGracePeriodNanoseconds)
            self?.endBackgroundTaskIfNeeded()
        }
    }

    private func handlePlaybackStarted() {
        if let activeRequest {
            Self.log("Playback started for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
        }
        hasStartedPlaybackForActiveRequest = true
        updateState(.playing)
    }

    private func presentPlaybackPreparationView() {
        isPlaybackPreparationViewPresented = true
        playbackPreparationProgress = 0
        playbackPreparationPhase = .preparing
    }

    private func dismissPlaybackPreparationView() {
        isPlaybackPreparationViewPresented = false
        playbackPreparationProgress = 0
        playbackPreparationPhase = .preparing
    }

    private func updatePlaybackPreparationProgress(
        bufferedSamples: Int,
        requiredSamples: Int,
        hasStartedPlayback: Bool
    ) {
        guard isPlaybackPreparationViewPresented else { return }
        guard requiredSamples > 0 else { return }

        let normalized = min(1, max(0, Double(bufferedSamples) / Double(requiredSamples)))
        playbackPreparationProgress = max(playbackPreparationProgress, normalized)
        if hasStartedPlayback, normalized >= 1 {
            playbackPreparationPhase = .readyToReturn
        }
    }

    private static func log(_ message: String) {
        NSLog("[TTSManager] %@", message)
    }
}
