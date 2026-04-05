import AVFoundation
import Foundation
import KeyVoxTTS

@MainActor
final class TTSPlaybackCoordinator {
    enum AudioSessionMode {
        case playback
        case playbackWhilePreservingRecording
    }

    enum MeterPolicy {
        static let windowSampleCount = 192
        static let windowStepCount = 96
        static let minimumUpdateLevel: Float = 0.015
    }

    var onPlaybackStarted: (() -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackCancelled: (() -> Void)?
    var onPlaybackFailed: ((Error) -> Void)?
    var onPlaybackPaused: (() -> Void)?
    var onPlaybackResumed: (() -> Void)?
    var onPreparationCompleted: (() -> Void)?
    var onPreparationProgress: ((Int, Int, Bool) -> Void)?
    var onPlaybackMeterLevel: ((Float) -> Void)?
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
    var playbackSessionID = UUID()

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
        let requiredSamples = backgroundContinuationBufferedSampleCount(
            for: lastObservedChunkCount,
            remainingEstimatedSamples: lastObservedRemainingEstimatedSamples
        )
        return queuedSampleCount >= requiredSamples
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
        didStartPlayback && playerNode.isPlaying && !isPaused
    }

    var canResumePlayback: Bool {
        didStartPlayback && isPaused
    }

    init() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)
    }

    func prepareForForegroundPlayback() {
        isBackgroundTransitionArmed = false
        Self.log("Foreground playback mode armed.")
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
            Self.log("Background transition armed before playback start.")
            return
        }

        isBackgroundTransitionArmed = true
        Self.log(
            "Background transition armed. bufferedSeconds=\(String(format: "%.3f", bufferedSeconds)) queuedBuffers=\(queuedBufferCount)"
        )
    }

    func didEnterBackground() {
        guard isBackgroundTransitionArmed else { return }
        Self.log(
            "Background continuation mode active. bufferedSeconds=\(String(format: "%.3f", bufferedSeconds)) queuedBuffers=\(queuedBufferCount)"
        )
    }

    static func log(_ message: String) {
        NSLog("[TTSPlaybackCoordinator] %@", message)
    }
}
