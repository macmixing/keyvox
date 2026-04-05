import Combine
import AVFoundation
import Foundation
import UIKit

@MainActor
final class TTSManager: ObservableObject {
    enum PlaybackPreparationPhase: Equatable {
        case preparing
        case readyToReturn
    }

    @Published var state: KeyVoxTTSState = .idle
    @Published var lastErrorMessage: String?
    @Published var isPlaybackPreparationViewPresented = false
    @Published var playbackPreparationProgress: Double = 0
    @Published var playbackPreparationPhase: PlaybackPreparationPhase = .preparing
    @Published var isPlaybackPaused = false
    @Published var hasReplayablePlayback = false
    @Published var isReplayingCachedPlayback = false
    @Published var playbackProgress: Double = 0
    @Published var fastModeBackgroundSafetyProgress: Double = 0
    @Published var isFastModeBackgroundSafe = false

    let settingsStore: AppSettingsStore
    let appHaptics: AppHapticsEmitting
    let keyboardBridge: KeyVoxKeyboardBridge
    let engine: any TTSEngine
    let playbackCoordinator: TTSPlaybackCoordinator
    let purchaseGate: any TTSPurchaseGating
    let replayCache: TTSReplayCache
    let effectiveVoiceProvider: @MainActor () -> AppSettingsStore.TTSVoice
    let onNewGenerationPlaybackStarted: @MainActor () -> Void
    var activeRequest: KeyVoxTTSRequest?
    var lastReplayableRequest: KeyVoxTTSRequest?
    var pausedReplaySampleOffset: Int?
    var hasStartedPlaybackForActiveRequest = false
    var didEmitPreparationCompletionForActiveRequest = false
    var shouldConsumeFreeSpeakOnPlaybackStart = false
    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    var backgroundTaskReleaseTask: Task<Void, Never>?
    var onWillTeardownPlayback: (() async -> Void)?

    var shouldPreventIdleSleep: Bool {
        TTSManagerPolicy.shouldPreventIdleSleep(for: state, isPlaybackPaused: isPlaybackPaused)
    }

    var isActive: Bool {
        TTSManagerPolicy.isActive(state)
    }

    var replayCurrentTimeSeconds: Double {
        playbackCoordinator.currentPlaybackSeconds
    }

    var replayDurationSeconds: Double {
        playbackCoordinator.totalPlaybackSeconds
    }

    var isCurrentRequestReplayReady: Bool {
        guard let activeRequest, let lastReplayableRequest else { return false }
        return hasReplayablePlayback && activeRequest.id == lastReplayableRequest.id
    }

    var currentPlaybackDisplayText: String? {
        if let activeRequest, activeRequest.trimmedText.isEmpty == false {
            return activeRequest.trimmedText
        }
        if hasReplayablePlayback,
           let lastReplayableRequest,
           lastReplayableRequest.trimmedText.isEmpty == false {
            return lastReplayableRequest.trimmedText
        }
        return nil
    }

    init(
        settingsStore: AppSettingsStore,
        appHaptics: AppHapticsEmitting,
        keyboardBridge: KeyVoxKeyboardBridge,
        engine: any TTSEngine,
        playbackCoordinator: TTSPlaybackCoordinator,
        purchaseGate: any TTSPurchaseGating,
        replayCache: TTSReplayCache? = nil,
        effectiveVoiceProvider: (@MainActor () -> AppSettingsStore.TTSVoice)? = nil,
        onNewGenerationPlaybackStarted: (@MainActor () -> Void)? = nil
    ) {
        self.settingsStore = settingsStore
        self.appHaptics = appHaptics
        self.keyboardBridge = keyboardBridge
        self.engine = engine
        self.playbackCoordinator = playbackCoordinator
        self.purchaseGate = purchaseGate
        self.replayCache = replayCache ?? TTSReplayCache()
        self.effectiveVoiceProvider = effectiveVoiceProvider ?? { settingsStore.ttsVoice }
        self.onNewGenerationPlaybackStarted = onNewGenerationPlaybackStarted ?? {}

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
            if let self {
                Self.log(
                    "Playback cancelled callback state=\(self.state.rawValue) paused=\(self.isPlaybackPaused) replaying=\(self.isReplayingCachedPlayback) pausedOffset=\(self.pausedReplaySampleOffset.map(String.init) ?? "nil") hasReplayable=\(self.hasReplayablePlayback)"
                )
            }
            self?.clearActiveRequest()
        }
        playbackCoordinator.onPlaybackFailed = { [weak self] error in
            self?.handleError(error.localizedDescription)
        }
        playbackCoordinator.onPlaybackMeterLevel = { [weak self] level in
            self?.keyboardBridge.publishPlaybackMeter(level: level)
        }
        playbackCoordinator.onPlaybackProgressChanged = { [weak self] progress in
            self?.playbackProgress = progress
        }
        playbackCoordinator.onPreparationProgress = { [weak self] bufferedSamples, requiredSamples, hasStartedPlayback in
            self?.updatePlaybackPreparationProgress(
                bufferedSamples: bufferedSamples,
                requiredSamples: requiredSamples,
                hasStartedPlayback: hasStartedPlayback
            )
        }
        playbackCoordinator.onFastModeBackgroundSafetyChanged = { [weak self] progress, isSafe in
            self?.fastModeBackgroundSafetyProgress = progress
            self?.isFastModeBackgroundSafe = isSafe
        }
        playbackCoordinator.onReplayablePlaybackReady = { [weak self] in
            self?.handleReplayablePlaybackReady()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruptionNotification(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChangeNotification(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        restoreReplayablePlaybackIfNeeded()
        updateIdleSleepPrevention()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    static func log(_ message: String) {
        #if DEBUG
        NSLog("[TTSManager] %@", message)
        #endif
    }
}
