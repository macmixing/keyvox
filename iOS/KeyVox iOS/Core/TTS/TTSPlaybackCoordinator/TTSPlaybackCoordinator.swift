import AVFoundation
import Foundation
import KeyVoxTTS
import UIKit

protocol TTSPlaybackAudioSessionControlling: AnyObject {
    var currentOutputPortTypes: [AVAudioSession.Port] { get }

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        policy: AVAudioSession.RouteSharingPolicy,
        options: AVAudioSession.CategoryOptions
    ) throws

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws

    func overrideOutputAudioPort(_ portOverride: AVAudioSession.PortOverride) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: TTSPlaybackAudioSessionControlling {
    var currentOutputPortTypes: [AVAudioSession.Port] {
        currentRoute.outputs.map(\.portType)
    }
}

@MainActor
final class TTSPlaybackCoordinator {
    enum AudioSessionMode {
        case playback
        case playbackWhilePreservingRecording
    }

    var onPlaybackStarted: (() -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackCancelled: (() -> Void)?
    var onPlaybackFailed: ((Error) -> Void)?
    var onPlaybackPaused: (() -> Void)?
    var onPlaybackResumed: (() -> Void)?
    var onPreparationCompleted: (() -> Void)?
    var onPreparationProgress: ((Int, Int, Bool) -> Void)?
    var onPlaybackProgressChanged: ((Double) -> Void)?
    var onFastModeBackgroundSafetyChanged: ((Double, Bool) -> Void)?
    var onReplayablePlaybackReady: (() -> Void)?

    let audioEngine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!

    var playbackTask: Task<Void, Never>?
    var queuedBufferCount = 0
    var queuedSampleCount = 0
    var isFinishing = false
    var didStartPlayback = false
    var pendingStartBuffers: [AVAudioPCMBuffer] = []
    var isBackgroundTransitionArmed = false
    var totalGeneratedSampleCount = 0
    var completedFastModeSegmentCount = 0
    var completedChunkCountBeforeStart = 0
    var hasBufferedIntoNextChunk = false
    var activeRequiredStartSampleCount = 0
    var activeSilentStartSampleCount = 0
    var scheduledMeterUpdates: [DispatchWorkItem] = []
    var audioSessionMode: AudioSessionMode = .playback
    var preparationCompletionDelaySeconds: Double = 0
    var fastModeEnabled = false
    var isWaitingForResumeBuffer = false
    var lastObservedChunkCount = 1
    var lastObservedRemainingEstimatedSamples = 0
    var totalScheduledSampleCount = 0
    var totalEstimatedPlaybackSampleCount = 0
    var isPaused = false
    var activePlaybackSamples: [Float] = []
    var replayablePlaybackSamples: [Float] = []
    var isReplayingCachedAudio = false
    var replayStartSampleOffset = 0
    var replayPausedSampleOffset = 0
    var playbackProgressDisplayLink: CADisplayLink?
    var backgroundPlaybackProgressTimer: Timer?
    var playbackSessionID = UUID()
    var isFastModeBackgroundSafeState = false
    var hasConfiguredAudioGraph = false
    var hasHandedOffPausedPlaybackSession = false
    var overrideIsPlayerNodePlaying: Bool?
    let audioSession: any TTSPlaybackAudioSessionControlling
    let preferBuiltInMicrophoneProvider: () -> Bool

    var hasReplayablePlayback: Bool {
        !replayablePlaybackSamples.isEmpty
    }

    var isReplayingCachedPlayback: Bool {
        isReplayingCachedAudio
    }

    var replayablePlaybackSampleCount: Int {
        replayablePlaybackSamples.count
    }

    var canContinueBackgroundPlaybackInFastMode: Bool {
        guard fastModeEnabled, didStartPlayback else { return false }
        if isReplayingCachedAudio {
            return true
        }
        return isFastModeBackgroundSafeState
    }

    var fastModeBackgroundSafetyProgress: Double {
        guard fastModeEnabled, didStartPlayback else { return 0 }
        let requiredSamples = backgroundContinuationBufferedSampleCount(
            for: lastObservedChunkCount,
            remainingEstimatedSamples: lastObservedRemainingEstimatedSamples
        )
        guard requiredSamples > 0 else { return 0 }
        return min(1, max(0, Double(queuedSampleCount) / Double(requiredSamples)))
    }

    var canPausePlayback: Bool {
        didStartPlayback && (overrideIsPlayerNodePlaying ?? playerNode.isPlaying) && !isPaused
    }

    var canResumePlayback: Bool {
        didStartPlayback && isPaused
    }

    init(
        audioSession: any TTSPlaybackAudioSessionControlling = AVAudioSession.sharedInstance(),
        preferBuiltInMicrophoneProvider: @escaping () -> Bool = { true }
    ) {
        self.audioSession = audioSession
        self.preferBuiltInMicrophoneProvider = preferBuiltInMicrophoneProvider
    }

    func configureAudioGraphIfNeeded() {
        guard hasConfiguredAudioGraph == false else { return }
        // Keep the graph lazy so cold launch does not interrupt external media playback.
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)
        hasConfiguredAudioGraph = true
    }

    func prepareForForegroundPlayback() {
        isBackgroundTransitionArmed = false
        if didStartPlayback && isPaused == false {
            startPlaybackProgressTimer()
        }
        notifyFastModeBackgroundSafetyChanged()
    }

    func setPreparationCompletionDelay(enabled: Bool) {
        preparationCompletionDelaySeconds = enabled ? TTSPlaybackCoordinatorBufferingPolicy.preparationCompletionDelaySeconds : 0
    }

    func setAudioSessionMode(_ mode: AudioSessionMode) {
        audioSessionMode = mode
        Self.log("Audio session mode set to \(String(describing: mode)).")
    }

    func prepareForBackgroundTransition() {
        guard didStartPlayback else {
            isBackgroundTransitionArmed = true
            return
        }

        isBackgroundTransitionArmed = true
    }

    func didEnterBackground() {
        guard isBackgroundTransitionArmed else { return }
        if didStartPlayback && isPaused == false {
            startPlaybackProgressTimer()
        }
    }

    static func log(_ message: String) {
        #if DEBUG
        NSLog("[TTSPlaybackCoordinator] %@", message)
        #endif
    }
}
