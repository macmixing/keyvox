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
    @Published private(set) var isPlaybackPaused = false
    @Published private(set) var hasReplayablePlayback = false

    private let settingsStore: AppSettingsStore
    private let appHaptics: AppHapticsEmitting
    private let keyboardBridge: KeyVoxKeyboardBridge
    private let engine: any TTSEngine
    private let playbackCoordinator: TTSPlaybackCoordinator
    private let replayCache: TTSReplayCache
    private let effectiveVoiceProvider: @MainActor () -> AppSettingsStore.TTSVoice
    private var activeRequest: KeyVoxTTSRequest?
    private var lastReplayableRequest: KeyVoxTTSRequest?
    private var pausedReplaySampleOffset: Int?
    private var hasStartedPlaybackForActiveRequest = false
    private var didEmitPreparationCompletionForActiveRequest = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTaskReleaseTask: Task<Void, Never>?
    var onWillTeardownPlayback: (() async -> Void)?

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
        appHaptics: AppHapticsEmitting,
        keyboardBridge: KeyVoxKeyboardBridge,
        engine: any TTSEngine,
        playbackCoordinator: TTSPlaybackCoordinator,
        replayCache: TTSReplayCache? = nil,
        effectiveVoiceProvider: (@MainActor () -> AppSettingsStore.TTSVoice)? = nil
    ) {
        self.settingsStore = settingsStore
        self.appHaptics = appHaptics
        self.keyboardBridge = keyboardBridge
        self.engine = engine
        self.playbackCoordinator = playbackCoordinator
        self.replayCache = replayCache ?? TTSReplayCache()
        self.effectiveVoiceProvider = effectiveVoiceProvider ?? { settingsStore.ttsVoice }

        playbackCoordinator.onPlaybackStarted = { [weak self] in
            self?.handlePlaybackStarted()
        }
        playbackCoordinator.onPreparationCompleted = { [weak self] in
            self?.handlePreparationCompleted()
        }
        playbackCoordinator.onPlaybackPaused = { [weak self] in
            self?.handlePlaybackPaused()
        }
        playbackCoordinator.onPlaybackResumed = { [weak self] in
            self?.handlePlaybackResumed()
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

        restoreReplayablePlaybackIfNeeded()
    }

    func handleAppDidBecomeActive() {
        Self.log("handleAppDidBecomeActive state=\(state.rawValue) backgroundTaskActive=\(backgroundTaskID != .invalid)")
        KeyVoxIPCBridge.touchHeartbeat()
        Task {
            await engine.prepareForForegroundSynthesis()
        }
        playbackCoordinator.prepareForForegroundPlayback()
        endBackgroundTaskIfNeeded()
    }

    func handleAppWillResignActive() {
        Self.log("handleAppWillResignActive state=\(state.rawValue) hasStartedPlayback=\(hasStartedPlaybackForActiveRequest)")
        guard isActive, hasStartedPlaybackForActiveRequest else { return }
        beginBackgroundTaskIfNeeded()

        let shouldPreserveForegroundSynthesisDuringTransition =
            activeRequest?.sourceSurface == .keyboard && playbackPreparationPhase != .readyToReturn
        if shouldPreserveForegroundSynthesisDuringTransition {
            Self.log("Delaying background-safe synthesis switch until playback is ready to return.")
        } else {
            Task {
                await engine.prepareForBackgroundContinuation()
            }
        }
        playbackCoordinator.prepareForBackgroundTransition()
    }

    func handleAppDidEnterBackground() {
        Self.log("handleAppDidEnterBackground state=\(state.rawValue) backgroundTaskActive=\(backgroundTaskID != .invalid)")
        isPlaybackPreparationViewPresented = false
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
            voiceID: effectiveVoiceProvider().rawValue,
            kind: .speakClipboardText
        )
        KeyVoxIPCBridge.writeTTSRequest(request)
        await startPlayback(request, showPreparationView: false)
    }

    func startPlaybackFromPendingRequest(showPreparationView: Bool = false) async {
        guard let request = KeyVoxIPCBridge.readTTSRequest(),
              request.trimmedText.isEmpty == false else {
            isPlaybackPreparationViewPresented = false
            resetPlaybackPreparationState()
            return
        }

        let effectiveVoiceID = effectiveVoiceProvider().rawValue
        let normalizedRequest: KeyVoxTTSRequest
        if request.voiceID == effectiveVoiceID {
            normalizedRequest = request
        } else {
            normalizedRequest = KeyVoxTTSRequest(
                id: request.id,
                text: request.text,
                createdAt: request.createdAt,
                sourceSurface: request.sourceSurface,
                voiceID: effectiveVoiceID,
                kind: request.kind
            )
        }

        await startPlayback(normalizedRequest, showPreparationView: showPreparationView)
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
        didEmitPreparationCompletionForActiveRequest = false
        isPlaybackPaused = false
        lastErrorMessage = nil
        resetPlaybackPreparationState()
        if showPreparationView {
            isPlaybackPreparationViewPresented = true
        } else {
            isPlaybackPreparationViewPresented = false
        }
        playbackCoordinator.setPreparationCompletionDelay(enabled: showPreparationView)
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

    func setPlaybackAudioSessionMode(_ mode: TTSPlaybackCoordinator.AudioSessionMode) {
        playbackCoordinator.setAudioSessionMode(mode)
    }

    func pausePlayback() {
        playbackCoordinator.pause()
    }

    func resumePlayback() {
        if playbackCoordinator.canResumePlayback == false,
           let pausedReplaySampleOffset,
           hasReplayablePlayback,
           let lastReplayableRequest {
            activeRequest = lastReplayableRequest
            hasStartedPlaybackForActiveRequest = true
            didEmitPreparationCompletionForActiveRequest = true
            isPlaybackPaused = false
            lastErrorMessage = nil
            resetPlaybackPreparationState()
            isPlaybackPreparationViewPresented = false
            beginBackgroundTaskIfNeeded()
            playbackCoordinator.replayLastPlayback(startingAtSample: pausedReplaySampleOffset)
            return
        }

        playbackCoordinator.resume()
    }

    func replayLastPlayback() {
        guard hasReplayablePlayback else { return }

        if let lastReplayableRequest {
            activeRequest = lastReplayableRequest
        }
        hasStartedPlaybackForActiveRequest = false
        didEmitPreparationCompletionForActiveRequest = true
        isPlaybackPaused = false
        pausedReplaySampleOffset = nil
        lastErrorMessage = nil
        resetPlaybackPreparationState()
        isPlaybackPreparationViewPresented = false
        beginBackgroundTaskIfNeeded()
        playbackCoordinator.replayLastPlayback()
    }

    func stopPlayback() async {
        if let activeRequest {
            Self.log("Stop requested for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
        } else {
            Self.log("Stop requested with no active request.")
        }
        playbackCoordinator.stop()
        await onWillTeardownPlayback?()
        KeyVoxIPCBridge.clearTTSRequest()
        keyboardBridge.publishTTSStopped()
        if let lastReplayableRequest {
            persistReplayablePlaybackIfNeeded(for: lastReplayableRequest)
        }
        clearActiveRequest()
    }

    private func finishPlayback() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let activeRequest {
                Self.log("Playback finished for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
                self.lastReplayableRequest = activeRequest
                self.persistReplayablePlaybackIfNeeded(for: activeRequest)
            } else {
                Self.log("Playback finished with no active request.")
            }
            self.hasReplayablePlayback = self.playbackCoordinator.hasReplayablePlayback
            self.isPlaybackPaused = false
            self.pausedReplaySampleOffset = nil
            await self.onWillTeardownPlayback?()
            KeyVoxIPCBridge.markRecentTTSPlayback()
            self.keyboardBridge.publishTTSFinished()
            self.clearActiveRequest()
        }
    }

    private func handleError(_ message: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let activeRequest {
                Self.log("Playback failed for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID) error=\(message)")
            } else {
                Self.log("Playback failed with no active request. error=\(message)")
            }
            self.lastErrorMessage = message
            self.isPlaybackPaused = false
            self.pausedReplaySampleOffset = nil
            self.updateState(.error)
            await self.onWillTeardownPlayback?()
            KeyVoxIPCBridge.markRecentTTSPlayback()
            self.keyboardBridge.publishTTSFailed(message: message)
            self.clearActiveRequest(clearPublishedState: false)
        }
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
        didEmitPreparationCompletionForActiveRequest = false
        isPlaybackPaused = false
        pausedReplaySampleOffset = nil
        hasReplayablePlayback = playbackCoordinator.hasReplayablePlayback
        KeyVoxIPCBridge.clearTTSRequest()
        isPlaybackPreparationViewPresented = false
        resetPlaybackPreparationState()
        playbackCoordinator.setPreparationCompletionDelay(enabled: false)
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
        Self.log("beginBackgroundTask id=\(backgroundTaskID.rawValue)")
        scheduleBackgroundTaskRelease()
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        Self.log("endBackgroundTask id=\(backgroundTaskID.rawValue)")
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
        isPlaybackPaused = false
        pausedReplaySampleOffset = nil
        hasReplayablePlayback = playbackCoordinator.hasReplayablePlayback
        updateState(.playing)
        if isPlaybackPreparationViewPresented {
            playbackPreparationProgress = 1
            playbackPreparationPhase = .readyToReturn
        }
    }

    private func handlePreparationCompleted() {
        playbackPreparationProgress = 1
        playbackPreparationPhase = .readyToReturn
        guard didEmitPreparationCompletionForActiveRequest == false else { return }
        didEmitPreparationCompletionForActiveRequest = true
        appHaptics.success()
    }

    private func handlePlaybackPaused() {
        Self.log("Playback paused.")
        isPlaybackPaused = true
        if let offset = playbackCoordinator.replayPausedSampleOffsetSnapshot(),
           let request = lastReplayableRequest ?? activeRequest,
           let samples = playbackCoordinator.replayablePlaybackSamplesSnapshot() {
            pausedReplaySampleOffset = offset
            replayCache.updatePauseState(
                request: request,
                sampleCount: samples.count,
                pausedSampleOffset: offset
            )
        }
    }

    private func handlePlaybackResumed() {
        Self.log("Playback resumed.")
        isPlaybackPaused = false
        pausedReplaySampleOffset = nil
        if let request = lastReplayableRequest ?? activeRequest,
           let samples = playbackCoordinator.replayablePlaybackSamplesSnapshot() {
            replayCache.updatePauseState(
                request: request,
                sampleCount: samples.count,
                pausedSampleOffset: nil
            )
        }
    }

    private func updatePlaybackPreparationProgress(
        bufferedSamples: Int,
        requiredSamples: Int,
        hasStartedPlayback: Bool
    ) {
        guard requiredSamples > 0 else { return }

        let normalized = min(1, max(0, Double(bufferedSamples) / Double(requiredSamples)))
        playbackPreparationProgress = max(playbackPreparationProgress, normalized)
        if hasStartedPlayback && playbackPreparationProgress >= 1 {
            playbackPreparationPhase = .readyToReturn
        }
    }

    private func resetPlaybackPreparationState() {
        playbackPreparationProgress = 0
        playbackPreparationPhase = .preparing
    }

    private func restoreReplayablePlaybackIfNeeded() {
        guard let snapshot = replayCache.load() else {
            hasReplayablePlayback = false
            return
        }

        lastReplayableRequest = snapshot.request
        playbackCoordinator.restoreReplayablePlayback(samples: snapshot.samples)
        hasReplayablePlayback = true
        if let pausedSampleOffset = snapshot.pausedSampleOffset,
           pausedSampleOffset > 0,
           pausedSampleOffset < snapshot.samples.count {
            pausedReplaySampleOffset = pausedSampleOffset
            activeRequest = snapshot.request
            hasStartedPlaybackForActiveRequest = true
            isPlaybackPaused = true
            state = .playing
        } else {
            pausedReplaySampleOffset = nil
        }
    }

    private func persistReplayablePlaybackIfNeeded(for request: KeyVoxTTSRequest) {
        guard let samples = playbackCoordinator.replayablePlaybackSamplesSnapshot() else { return }
        replayCache.save(request: request, samples: samples, pausedSampleOffset: nil)
    }

    private static func log(_ message: String) {
        NSLog("[TTSManager] %@", message)
    }
}
