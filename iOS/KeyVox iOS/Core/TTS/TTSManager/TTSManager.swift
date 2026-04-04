import Combine
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
    let replayCache: TTSReplayCache
    let effectiveVoiceProvider: @MainActor () -> AppSettingsStore.TTSVoice
    var activeRequest: KeyVoxTTSRequest?
    var lastReplayableRequest: KeyVoxTTSRequest?
    var pausedReplaySampleOffset: Int?
    var hasStartedPlaybackForActiveRequest = false
    var didEmitPreparationCompletionForActiveRequest = false
    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    var backgroundTaskReleaseTask: Task<Void, Never>?
    var onWillTeardownPlayback: (() async -> Void)?

    var shouldPreventIdleSleep: Bool {
        TTSManagerPolicy.shouldPreventIdleSleep(for: state, isPlaybackPaused: isPlaybackPaused)
    }

    var isActive: Bool {
        TTSManagerPolicy.isActive(state)
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

        restoreReplayablePlaybackIfNeeded()
        updateIdleSleepPrevention()
    }

    static func log(_ message: String) {
        NSLog("[TTSManager] %@", message)
    }
}
