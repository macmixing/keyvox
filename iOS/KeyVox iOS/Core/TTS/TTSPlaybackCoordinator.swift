import AVFoundation
import Foundation
import KeyVoxTTS

@MainActor
final class TTSPlaybackCoordinator {
    enum AudioSessionMode {
        case playback
        case playbackWhilePreservingRecording
    }

    private enum BufferPolicy {
        static let singleChunkStartBufferedSeconds: Double = 0.45
        static let multiChunkMinimumRunwaySeconds: Double = 1.2
        static let fastModeSingleChunkStartBufferedSeconds: Double = 0.30
        static let fastModeMultiChunkMinimumRunwaySeconds: Double = 0.60
        static let fastModeSingleChunkCoverageFraction: Double = 0.45
        static let fastModeSingleChunkMinimumCoverageSeconds: Double = 1.8
        static let fastModeSingleChunkMaximumCoverageSeconds: Double = 3.4
        static let fastModeMinimumCoverageSeconds: Double = 1.35
        static let fastModeLongFormMinimumCoverageSeconds: Double = 2.4
        static let fastModeUltraLongFormMinimumCoverageSeconds: Double = 3.2
        static let conservativeForegroundRealtimeFactor: Double = 0.88
        static let longFormForegroundRealtimeFactor: Double = 0.80
        static let ultraLongFormForegroundRealtimeFactor: Double = 0.72
        static let returnToHostRunwaySeconds: Double = 6.0
        static let conservativeBackgroundRealtimeFactor: Double = 0.58
        static let remainingWorkSafetyMarginSeconds: Double = 2.5
        static let fastModeRemainingWorkSafetyMarginSeconds: Double = 0.35
        static let longFormChunkThreshold = 24
        static let ultraLongFormChunkThreshold = 64
        static let longFormBackgroundRealtimeFactor: Double = 0.52
        static let ultraLongFormBackgroundRealtimeFactor: Double = 0.42
        static let maximumBaseDeterministicRunwaySeconds: Double = 90.0
        static let preparationCompletionDelaySeconds: Double = 0.5
    }

    private enum MeterPolicy {
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

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!

    private var playbackTask: Task<Void, Never>?
    private var queuedBufferCount = 0
    private var queuedSampleCount = 0
    private var isFinishing = false
    private var didStartPlayback = false
    private var pendingStartBuffers: [AVAudioPCMBuffer] = []
    private var isBackgroundTransitionArmed = false
    private var totalGeneratedSampleCount = 0
    private var completedFastModeSegmentCount = 0
    private var completedChunkCountBeforeStart = 0
    private var hasBufferedIntoNextChunk = false
    private var activeRequiredStartSampleCount = 0
    private var activeSilentStartSampleCount = 0
    private var scheduledMeterUpdates: [DispatchWorkItem] = []
    private var audioSessionMode: AudioSessionMode = .playback
    private var preparationCompletionDelaySeconds: Double = 0
    private var fastModeEnabled = false
    private var isWaitingForResumeBuffer = false
    private var lastObservedChunkCount = 1
    private var lastObservedRemainingEstimatedSamples = 0
    private var totalScheduledSampleCount = 0
    private var totalEstimatedPlaybackSampleCount = 0
    private var isPaused = false
    private var activePlaybackSamples: [Float] = []
    private var replayablePlaybackSamples: [Float] = []
    private var isReplayingCachedAudio = false
    private var replayStartSampleOffset = 0
    private var replayPausedSampleOffset = 0
    private var playbackProgressDisplayLink: CADisplayLink?

    var hasReplayablePlayback: Bool {
        !replayablePlaybackSamples.isEmpty
    }

    var isReplayingCachedPlayback: Bool {
        isReplayingCachedAudio
    }

    var canContinueBackgroundPlaybackInFastMode: Bool {
        guard fastModeEnabled, didStartPlayback else { return false }
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

    func restoreReplayablePlayback(samples: [Float]) {
        replayablePlaybackSamples = samples
    }

    func replayablePlaybackSamplesSnapshot() -> [Float]? {
        guard !replayablePlaybackSamples.isEmpty else { return nil }
        return replayablePlaybackSamples
    }

    func replayPausedSampleOffsetSnapshot() -> Int? {
        guard !replayablePlaybackSamples.isEmpty else { return nil }
        guard replayPausedSampleOffset > 0, replayPausedSampleOffset < replayablePlaybackSamples.count else {
            return nil
        }
        return replayPausedSampleOffset
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
        preparationCompletionDelaySeconds = enabled ? BufferPolicy.preparationCompletionDelaySeconds : 0
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

    func play(_ stream: AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>, fastModeEnabled: Bool = false) {
        stop(emitCallback: false)
        Self.log("Playback requested. fastMode=\(fastModeEnabled)")

        do {
            try configureAudioSession()
            if audioEngine.isRunning == false {
                try audioEngine.start()
            }
        } catch {
            Self.log("Playback setup failed: \(error.localizedDescription)")
            onPlaybackFailed?(error)
            return
        }

        queuedBufferCount = 0
        queuedSampleCount = 0
        isFinishing = false
        didStartPlayback = false
        pendingStartBuffers = []
        totalGeneratedSampleCount = 0
        completedFastModeSegmentCount = 0
        completedChunkCountBeforeStart = 0
        hasBufferedIntoNextChunk = false
        isBackgroundTransitionArmed = false
        activeRequiredStartSampleCount = 0
        activeSilentStartSampleCount = 0
        isWaitingForResumeBuffer = false
        lastObservedChunkCount = 1
        lastObservedRemainingEstimatedSamples = 0
        totalScheduledSampleCount = 0
        totalEstimatedPlaybackSampleCount = 0
        cancelScheduledMeterUpdates()
        stopPlaybackProgressTimer()
        isPaused = false
        activePlaybackSamples = []
        isReplayingCachedAudio = false
        replayStartSampleOffset = 0
        replayPausedSampleOffset = 0
        self.fastModeEnabled = fastModeEnabled
        notifyFastModeBackgroundSafetyChanged()

        playbackTask = Task { [weak self] in
            guard let self else { return }

            do {
                for try await frame in stream {
                    guard Task.isCancelled == false else { return }
                    await MainActor.run {
                        self.schedule(frame)
                    }
                }

                await MainActor.run {
                    self.isFinishing = true
                    Self.log("Playback stream finished. queuedBuffers=\(self.queuedBufferCount) queuedSamples=\(self.queuedSampleCount)")
                    self.finishIfPossible()
                }
            } catch {
                await MainActor.run {
                    Self.log("Playback stream failed: \(error.localizedDescription)")
                    self.handleFailure(error)
                }
            }
        }
    }

    func stop() {
        stop(emitCallback: true)
    }

    func pause() {
        guard canPausePlayback else { return }
        if isReplayingCachedAudio {
            replayPausedSampleOffset = currentReplaySampleOffset()
        }
        playerNode.pause()
        isPaused = true
        cancelScheduledMeterUpdates()
        emitPlaybackProgress()
        Self.log("Playback paused.")
        notifyFastModeBackgroundSafetyChanged()
        onPlaybackPaused?()
    }

    func resume() {
        guard canResumePlayback else { return }
        if shouldDelayResumeUntilBuffered() {
            isWaitingForResumeBuffer = true
            let requiredSamples = deterministicFastModeBufferedSampleCount(
                for: lastObservedChunkCount,
                remainingEstimatedSamples: lastObservedRemainingEstimatedSamples
            )
            Self.log(
                "Delaying playback resume for buffer refill. queuedSeconds=\(String(format: "%.3f", bufferedSeconds)) requiredSeconds=\(String(format: "%.3f", Double(requiredSamples) / playbackFormat.sampleRate)) generatedSeconds=\(String(format: "%.3f", Double(totalGeneratedSampleCount) / playbackFormat.sampleRate))"
            )
            resumeIfBufferedEnough()
            return
        }

        playerNode.play()
        isPaused = false
        isWaitingForResumeBuffer = false
        if isReplayingCachedAudio {
            replayPausedSampleOffset = 0
        }
        startPlaybackProgressTimer()
        emitPlaybackProgress()
        Self.log("Playback resumed.")
        notifyFastModeBackgroundSafetyChanged()
        onPlaybackResumed?()
    }

    func replayLastPlayback(startingAtSample startSampleOffset: Int = 0) {
        guard !replayablePlaybackSamples.isEmpty else { return }

        stop(emitCallback: false)
        let safeStartSampleOffset = min(max(0, startSampleOffset), max(0, replayablePlaybackSamples.count - 1))
        Self.log("Replaying cached playback samples=\(replayablePlaybackSamples.count) startOffset=\(safeStartSampleOffset)")

        do {
            try configureAudioSession()
            if audioEngine.isRunning == false {
                try audioEngine.start()
            }
        } catch {
            Self.log("Replay setup failed: \(error.localizedDescription)")
            onPlaybackFailed?(error)
            return
        }

        queuedBufferCount = 0
        queuedSampleCount = 0
        isFinishing = false
        didStartPlayback = true
        isPaused = false
        pendingStartBuffers = []
        completedChunkCountBeforeStart = 0
        hasBufferedIntoNextChunk = false
        isBackgroundTransitionArmed = false
        activeRequiredStartSampleCount = 0
        activeSilentStartSampleCount = 0
        totalScheduledSampleCount = 0
        totalEstimatedPlaybackSampleCount = 0
        cancelScheduledMeterUpdates()
        stopPlaybackProgressTimer()
        activePlaybackSamples = replayablePlaybackSamples
        totalEstimatedPlaybackSampleCount = replayablePlaybackSamples.count
        isReplayingCachedAudio = true
        replayStartSampleOffset = safeStartSampleOffset
        replayPausedSampleOffset = 0

        let bufferSampleCount = Int(playbackFormat.sampleRate * 0.5)
        var startDelay: TimeInterval = 0
        var cursor = safeStartSampleOffset
        while cursor < replayablePlaybackSamples.count {
            let end = min(cursor + bufferSampleCount, replayablePlaybackSamples.count)
            let slice = Array(replayablePlaybackSamples[cursor..<end])
            guard let buffer = makeBuffer(from: slice) else {
                handleFailure(KeyVoxTTSError.inferenceFailure("PocketTTS replay buffer creation failed."))
                return
            }
            scheduleBuffer(
                buffer,
                samples: slice,
                chunkDebugID: "cached-replay",
                chunkIndex: nil,
                startDelay: startDelay
            )
            startDelay += TimeInterval(slice.count) / playbackFormat.sampleRate
            cursor = end
        }

        isFinishing = true
        playerNode.play()
        startPlaybackProgressTimer()
        emitPlaybackProgress()
        onPlaybackStarted?()
    }

    private func stop(emitCallback: Bool) {
        let hadPlayback = playbackTask != nil || playerNode.isPlaying || queuedBufferCount > 0
        Self.log("Stopping playback. hadPlayback=\(hadPlayback) queuedBuffers=\(queuedBufferCount) queuedSamples=\(queuedSampleCount)")

        playbackTask?.cancel()
        playbackTask = nil
        queuedBufferCount = 0
        queuedSampleCount = 0
        isFinishing = false
        didStartPlayback = false
        pendingStartBuffers.removeAll(keepingCapacity: false)
        totalGeneratedSampleCount = 0
        completedFastModeSegmentCount = 0
        completedChunkCountBeforeStart = 0
        hasBufferedIntoNextChunk = false
        isBackgroundTransitionArmed = false
        activeRequiredStartSampleCount = 0
        activeSilentStartSampleCount = 0
        isWaitingForResumeBuffer = false
        lastObservedChunkCount = 1
        lastObservedRemainingEstimatedSamples = 0
        totalScheduledSampleCount = 0
        totalEstimatedPlaybackSampleCount = 0
        cancelScheduledMeterUpdates()
        stopPlaybackProgressTimer()
        isPaused = false
        activePlaybackSamples = []
        isReplayingCachedAudio = false
        replayStartSampleOffset = 0
        replayPausedSampleOffset = 0

        if playerNode.isPlaying {
            playerNode.stop()
        }
        audioEngine.stop()
        deactivateAudioSessionIfNeeded()

        if emitCallback, hadPlayback {
            onPlaybackCancelled?()
        }
        notifyFastModeBackgroundSafetyChanged()
        emitPlaybackProgress()
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        switch audioSessionMode {
        case .playback:
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? session.overrideOutputAudioPort(.none)
        case .playbackWhilePreservingRecording:
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
            )
            let isUsingBuiltInReceiver = session.currentRoute.outputs.contains { $0.portType == .builtInReceiver }
            try? session.overrideOutputAudioPort(isUsingBuiltInReceiver ? .speaker : .none)
        }
        try session.setActive(true)
    }

    private func schedule(_ frame: KeyVoxTTSAudioFrame) {
        lastObservedChunkCount = frame.chunkCount
        lastObservedRemainingEstimatedSamples = frame.estimatedRemainingSampleCount
        recordCompletedFastModeSegmentIfNeeded(from: frame)
        if totalEstimatedPlaybackSampleCount == 0 {
            totalEstimatedPlaybackSampleCount = totalGeneratedSampleCount + frame.sampleCount + frame.estimatedRemainingSampleCount
        }

        if frame.samples.isEmpty {
            handleChunkBoundary(frame)
            resumeIfBufferedEnough()
            emitPlaybackProgress()
            notifyFastModeBackgroundSafetyChanged()
            return
        }

        totalGeneratedSampleCount += frame.sampleCount
        activePlaybackSamples.append(contentsOf: frame.samples)
        guard let buffer = makeBuffer(from: frame.samples) else {
            handleFailure(KeyVoxTTSError.inferenceFailure("PocketTTS produced an invalid audio frame."))
            return
        }

        if didStartPlayback == false {
            pendingStartBuffers.append(buffer)
            queuedSampleCount += frame.sampleCount

            let isLastChunk = frame.chunkIndex == frame.chunkCount - 1
            if frame.isChunkFinalBatch {
                completedChunkCountBeforeStart += 1
            } else if frame.chunkIndex > 0 {
                hasBufferedIntoNextChunk = true
            }

            let requiredBufferedSamples = fastModeEnabled
                ? fastModeRequiredStartSampleCount(for: frame.chunkCount)
                : normalModeRequiredStartSampleCount(for: frame.chunkCount)
            activeRequiredStartSampleCount = requiredBufferedSamples
            let silentStartRequirement = fastModeEnabled
                ? deterministicFastModeBufferedSampleCount(
                    for: frame.chunkCount,
                    remainingEstimatedSamples: frame.estimatedRemainingSampleCount
                )
                : normalModeBufferedSampleCount(
                    for: frame.chunkCount,
                    remainingEstimatedSamples: frame.estimatedRemainingSampleCount,
                    requiredStartSamples: requiredBufferedSamples,
                    minimumCoverageSeconds: BufferPolicy.returnToHostRunwaySeconds,
                    realtimeFactor: backgroundRealtimeFactor(for: frame.chunkCount),
                    remainingWorkSafetyMarginSeconds: BufferPolicy.remainingWorkSafetyMarginSeconds,
                    allowFullRemainingDeficit: false
                )
            activeSilentStartSampleCount = max(activeSilentStartSampleCount, silentStartRequirement)
            let requiredBufferedSeconds = Double(requiredBufferedSamples) / playbackFormat.sampleRate
            let hasEnoughBufferedAudio = queuedSampleCount >= activeSilentStartSampleCount
            let hasObservedChunkRunway = canStartFastModeSegmentedPlayback(
                chunkCount: frame.chunkCount,
                hasEnoughBufferedAudio: hasEnoughBufferedAudio
            )
            onPreparationProgress?(
                min(queuedSampleCount, activeSilentStartSampleCount),
                activeSilentStartSampleCount,
                false
            )
            Self.log(
                "Prebuffering chunk=\(frame.chunkIndex + 1)/\(frame.chunkCount) chunkID=\(frame.chunkDebugID) frameIndex=\(frame.frameIndex) queuedSamples=\(queuedSampleCount) requiredSamples=\(requiredBufferedSamples) silentStartSamples=\(activeSilentStartSampleCount) remainingEstimatedSamples=\(frame.estimatedRemainingSampleCount) requiredSeconds=\(String(format: "%.3f", requiredBufferedSeconds))"
            )
            if hasObservedChunkRunway || (isLastChunk && frame.isChunkFinalBatch) {
                flushPendingStartBuffers()
            }
            return
        }

        scheduleBuffer(buffer, samples: frame.samples, chunkDebugID: frame.chunkDebugID, chunkIndex: frame.chunkIndex)
        resumeIfBufferedEnough()
        emitPlaybackProgress()
        notifyFastModeBackgroundSafetyChanged()
    }

    private func handleChunkBoundary(_ frame: KeyVoxTTSAudioFrame) {
        let isLastChunk = frame.chunkIndex == frame.chunkCount - 1

        if didStartPlayback == false {
            if frame.isChunkFinalBatch {
                completedChunkCountBeforeStart += 1
            } else if frame.chunkIndex > 0 {
                hasBufferedIntoNextChunk = true
            }

            let requiredBufferedSamples = fastModeEnabled
                ? fastModeRequiredStartSampleCount(for: frame.chunkCount)
                : normalModeRequiredStartSampleCount(for: frame.chunkCount)
            activeRequiredStartSampleCount = requiredBufferedSamples
            let silentStartRequirement = fastModeEnabled
                ? deterministicFastModeBufferedSampleCount(
                    for: frame.chunkCount,
                    remainingEstimatedSamples: frame.estimatedRemainingSampleCount
                )
                : normalModeBufferedSampleCount(
                    for: frame.chunkCount,
                    remainingEstimatedSamples: frame.estimatedRemainingSampleCount,
                    requiredStartSamples: requiredBufferedSamples,
                    minimumCoverageSeconds: BufferPolicy.returnToHostRunwaySeconds,
                    realtimeFactor: backgroundRealtimeFactor(for: frame.chunkCount),
                    remainingWorkSafetyMarginSeconds: BufferPolicy.remainingWorkSafetyMarginSeconds,
                    allowFullRemainingDeficit: false
                )
            activeSilentStartSampleCount = max(activeSilentStartSampleCount, silentStartRequirement)
            let requiredBufferedSeconds = Double(requiredBufferedSamples) / playbackFormat.sampleRate
            let hasEnoughBufferedAudio = queuedSampleCount >= activeSilentStartSampleCount
            let hasObservedChunkRunway = canStartFastModeSegmentedPlayback(
                chunkCount: frame.chunkCount,
                hasEnoughBufferedAudio: hasEnoughBufferedAudio
            )
            onPreparationProgress?(
                min(queuedSampleCount, activeSilentStartSampleCount),
                activeSilentStartSampleCount,
                false
            )
            Self.log(
                "Prebuffering chunk=\(frame.chunkIndex + 1)/\(frame.chunkCount) chunkID=\(frame.chunkDebugID) frameIndex=\(frame.frameIndex) queuedSamples=\(queuedSampleCount) requiredSamples=\(requiredBufferedSamples) silentStartSamples=\(activeSilentStartSampleCount) remainingEstimatedSamples=\(frame.estimatedRemainingSampleCount) requiredSeconds=\(String(format: "%.3f", requiredBufferedSeconds))"
            )
            if hasObservedChunkRunway || (isLastChunk && frame.isChunkFinalBatch) {
                flushPendingStartBuffers()
            }
        }
    }

    private func makeBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        guard let channel = buffer.floatChannelData?.pointee else {
            return nil
        }

        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            channel.update(from: baseAddress, count: samples.count)
        }
        return buffer
    }

    private func finishIfPossible() {
        guard isFinishing, queuedBufferCount == 0, pendingStartBuffers.isEmpty else { return }
        Self.log("Playback finished.")

        playbackTask = nil
        replayablePlaybackSamples = activePlaybackSamples
        activePlaybackSamples = []
        isPaused = false
        isReplayingCachedAudio = false
        replayStartSampleOffset = 0
        replayPausedSampleOffset = 0
        if playerNode.isPlaying {
            playerNode.stop()
        }
        audioEngine.stop()
        cancelScheduledMeterUpdates()
        stopPlaybackProgressTimer()
        emitPlaybackProgress(1)
        deactivateAudioSessionIfNeeded()
        onPlaybackFinished?()
    }

    private func deactivateAudioSessionIfNeeded() {
        guard audioSessionMode == .playback else {
            Self.log("Preserving active audio session after playback finish.")
            return
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func handleFailure(_ error: Error) {
        Self.log("Playback failure: \(error.localizedDescription)")
        stop(emitCallback: false)
        onPlaybackFailed?(error)
    }

    private func flushPendingStartBuffers() {
        guard didStartPlayback == false else { return }
        guard !pendingStartBuffers.isEmpty else { return }

        let buffered = pendingStartBuffers
        pendingStartBuffers.removeAll(keepingCapacity: true)
        queuedSampleCount = 0
        let bufferedSamples = buffered.reduce(0) { $0 + Int($1.frameLength) }
        var startDelay: TimeInterval = 0

        for buffer in buffered {
            let samples = copySamples(from: buffer)
            scheduleBuffer(
                buffer,
                samples: samples,
                chunkDebugID: "startup-buffer",
                chunkIndex: nil,
                startDelay: startDelay
            )
            startDelay += TimeInterval(buffer.frameLength) / playbackFormat.sampleRate
        }

        didStartPlayback = true
        onPreparationProgress?(activeSilentStartSampleCount, activeSilentStartSampleCount, false)
        onPreparationCompleted?()
        notifyFastModeBackgroundSafetyChanged()

        let startPlayback = { [weak self] in
            guard let self else { return }
            self.playerNode.play()
            self.startPlaybackProgressTimer()
            self.onPreparationProgress?(self.activeSilentStartSampleCount, self.activeSilentStartSampleCount, true)
            Self.log("Playback started with bufferedSamples=\(bufferedSamples) queuedBuffers=\(self.queuedBufferCount)")
            self.emitPlaybackProgress()
            self.notifyFastModeBackgroundSafetyChanged()
            self.onPlaybackStarted?()
        }

        if preparationCompletionDelaySeconds > 0 {
            Self.log(
                "Preparation reached 100%; delaying playback start by \(String(format: "%.3f", preparationCompletionDelaySeconds))s"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + preparationCompletionDelaySeconds) {
                startPlayback()
            }
        } else {
            startPlayback()
        }
    }

    private func scheduleBuffer(
        _ buffer: AVAudioPCMBuffer,
        samples: [Float],
        chunkDebugID: String,
        chunkIndex: Int?,
        startDelay: TimeInterval? = nil
    ) {
        let sampleCount = Int(buffer.frameLength)
        let bufferStartDelay = startDelay ?? (Double(queuedSampleCount) / playbackFormat.sampleRate)
        queuedBufferCount += 1
        queuedSampleCount += sampleCount
        totalScheduledSampleCount += sampleCount
        scheduleMeterUpdates(for: samples, startDelay: bufferStartDelay)
        let queuedSeconds = Double(queuedSampleCount) / playbackFormat.sampleRate
        if queuedBufferCount == 1 || queuedSeconds < 0.25 {
            Self.log(
                "Scheduling buffer chunk=\(chunkIndex.map { String($0 + 1) } ?? "-") chunkID=\(chunkDebugID) sampleCount=\(sampleCount) queuedBuffers=\(queuedBufferCount) queuedSeconds=\(String(format: "%.3f", queuedSeconds))"
            )
        }
        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.queuedBufferCount = max(0, self.queuedBufferCount - 1)
                self.queuedSampleCount = max(0, self.queuedSampleCount - sampleCount)
                let remainingSeconds = Double(self.queuedSampleCount) / self.playbackFormat.sampleRate
                if self.queuedBufferCount == 0 || remainingSeconds < 0.25 {
                    Self.log(
                        "Buffer completed chunk=\(chunkIndex.map { String($0 + 1) } ?? "-") chunkID=\(chunkDebugID) sampleCount=\(sampleCount) remainingBuffers=\(self.queuedBufferCount) remainingSeconds=\(String(format: "%.3f", remainingSeconds))"
                    )
                }
                self.emitPlaybackProgress()
                self.notifyFastModeBackgroundSafetyChanged()
                self.finishIfPossible()
            }
        }
    }

    private func scheduleMeterUpdates(for samples: [Float], startDelay: TimeInterval) {
        guard !samples.isEmpty else { return }

        let sampleRate = playbackFormat.sampleRate
        let now = DispatchTime.now()
        var windowStart = 0

        while windowStart < samples.count {
            let windowEnd = min(windowStart + MeterPolicy.windowSampleCount, samples.count)
            let windowSamples = Array(samples[windowStart..<windowEnd])
            let meterLevel = max(playbackMeterLevel(for: windowSamples), MeterPolicy.minimumUpdateLevel)
            let windowOffset = TimeInterval(windowStart) / sampleRate
            let workItem = DispatchWorkItem { [weak self] in
                self?.onPlaybackMeterLevel?(meterLevel)
            }
            scheduledMeterUpdates.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: now + startDelay + windowOffset, execute: workItem)

            if windowEnd == samples.count {
                break
            }

            windowStart += MeterPolicy.windowStepCount
        }
    }

    private func cancelScheduledMeterUpdates() {
        scheduledMeterUpdates.forEach { $0.cancel() }
        scheduledMeterUpdates.removeAll(keepingCapacity: false)
    }

    private func copySamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channel = buffer.floatChannelData?.pointee else { return [] }
        let frameLength = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channel, count: frameLength))
    }

    private func playbackMeterLevel(for samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        var peak: Float = 0
        let meanSquare = samples.reduce(Float.zero) { partialResult, sample in
            let magnitude = abs(sample)
            peak = max(peak, magnitude)
            return partialResult + (sample * sample)
        } / Float(samples.count)

        let rms = sqrt(meanSquare)
        let rmsDriven = rms * 8.8
        let peakDriven = peak * 2.1
        return min(max(max(rmsDriven, peakDriven), 0), 1)
    }

    private func currentReplaySampleOffset() -> Int {
        guard isReplayingCachedAudio else { return 0 }
        guard let renderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: renderTime) else {
            return replayPausedSampleOffset
        }

        let currentOffset = replayStartSampleOffset + Int(playerTime.sampleTime)
        return min(max(0, currentOffset), replayablePlaybackSamples.count)
    }

    private var bufferedSeconds: Double {
        Double(queuedSampleCount) / playbackFormat.sampleRate
    }

    private func recordCompletedFastModeSegmentIfNeeded(from frame: KeyVoxTTSAudioFrame) {
        guard fastModeEnabled, frame.isChunkFinalBatch else { return }
        guard let chunkGeneratedSampleCount = frame.chunkGeneratedSampleCount,
              chunkGeneratedSampleCount > 0 else {
            return
        }

        completedFastModeSegmentCount += 1
    }

    private func canStartFastModeSegmentedPlayback(chunkCount: Int, hasEnoughBufferedAudio: Bool) -> Bool {
        guard hasEnoughBufferedAudio else { return false }
        guard fastModeEnabled, chunkCount > 1 else {
            return chunkCount == 1
                ? hasEnoughBufferedAudio
                : completedChunkCountBeforeStart >= 1 && hasBufferedIntoNextChunk && hasEnoughBufferedAudio
        }

        let requiredCompletedSegments = minimumCompletedFastModeSegmentLead(for: chunkCount)

        return completedFastModeSegmentCount >= requiredCompletedSegments
            && completedChunkCountBeforeStart >= requiredCompletedSegments
            && hasBufferedIntoNextChunk
    }

    private func shouldDelayResumeUntilBuffered() -> Bool {
        guard fastModeEnabled, !isReplayingCachedAudio else { return false }
        return queuedSampleCount < deterministicFastModeBufferedSampleCount(
            for: lastObservedChunkCount,
            remainingEstimatedSamples: lastObservedRemainingEstimatedSamples
        )
    }

    private func resumeIfBufferedEnough() {
        guard isWaitingForResumeBuffer else { return }
        let requiredSamples = deterministicFastModeBufferedSampleCount(
            for: lastObservedChunkCount,
            remainingEstimatedSamples: lastObservedRemainingEstimatedSamples
        )
        guard queuedSampleCount >= requiredSamples || (isFinishing && queuedSampleCount > 0) else { return }

        playerNode.play()
        isPaused = false
        isWaitingForResumeBuffer = false
        if isReplayingCachedAudio {
            replayPausedSampleOffset = 0
        }
        startPlaybackProgressTimer()
        emitPlaybackProgress()
        Self.log(
            "Playback resumed after buffer refill. queuedSeconds=\(String(format: "%.3f", bufferedSeconds)) requiredSeconds=\(String(format: "%.3f", Double(requiredSamples) / playbackFormat.sampleRate)) generatedSeconds=\(String(format: "%.3f", Double(totalGeneratedSampleCount) / playbackFormat.sampleRate))"
        )
        notifyFastModeBackgroundSafetyChanged()
        onPlaybackResumed?()
    }

    private func startPlaybackProgressTimer() {
        guard playbackProgressDisplayLink == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(handlePlaybackProgressDisplayLinkTick))
        if #available(iOS 15.0, *) {
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        } else {
            displayLink.preferredFramesPerSecond = 60
        }
        playbackProgressDisplayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    private func stopPlaybackProgressTimer() {
        playbackProgressDisplayLink?.invalidate()
        playbackProgressDisplayLink = nil
    }

    @objc
    private func handlePlaybackProgressDisplayLinkTick() {
        emitPlaybackProgress()
    }

    private func emitPlaybackProgress(_ overrideProgress: Double? = nil) {
        let progress = overrideProgress ?? currentPlaybackProgress
        onPlaybackProgressChanged?(min(1, max(0, progress)))
    }

    private var currentPlaybackProgress: Double {
        let denominator = currentPlaybackProgressDenominator
        guard denominator > 0 else { return 0 }
        return Double(currentPlaybackSampleOffset) / Double(denominator)
    }

    private var currentPlaybackProgressDenominator: Int {
        if isReplayingCachedAudio {
            return replayablePlaybackSamples.count
        }
        return max(totalEstimatedPlaybackSampleCount, totalScheduledSampleCount)
    }

    private var currentPlaybackSampleOffset: Int {
        if isReplayingCachedAudio {
            return currentReplaySampleOffset()
        }
        guard let renderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: renderTime) else {
            let playedSamples = max(0, totalScheduledSampleCount - queuedSampleCount)
            return min(playedSamples, currentPlaybackProgressDenominator)
        }
        let playedSamples = max(0, Int(playerTime.sampleTime))
        return min(playedSamples, currentPlaybackProgressDenominator)
    }

    private func notifyFastModeBackgroundSafetyChanged() {
        onFastModeBackgroundSafetyChanged?(
            fastModeBackgroundSafetyProgress,
            canContinueBackgroundPlaybackInFastMode
        )
    }

    private func deterministicFastModeBufferedSampleCount(for chunkCount: Int, remainingEstimatedSamples: Int) -> Int {
        let requiredStartSamples = fastModeRequiredStartSampleCount(for: chunkCount)
        return normalModeBufferedSampleCount(
            for: chunkCount,
            remainingEstimatedSamples: remainingEstimatedSamples,
            requiredStartSamples: requiredStartSamples,
            minimumCoverageSeconds: fastModeMinimumCoverageSeconds(for: chunkCount),
            realtimeFactor: foregroundRealtimeFactor(for: chunkCount),
            remainingWorkSafetyMarginSeconds: BufferPolicy.fastModeRemainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: true
        )
    }

    private func backgroundContinuationBufferedSampleCount(for chunkCount: Int, remainingEstimatedSamples: Int) -> Int {
        normalModeBufferedSampleCount(
            for: chunkCount,
            remainingEstimatedSamples: remainingEstimatedSamples,
            requiredStartSamples: normalModeRequiredStartSampleCount(for: chunkCount),
            minimumCoverageSeconds: BufferPolicy.returnToHostRunwaySeconds,
            realtimeFactor: backgroundRealtimeFactor(for: chunkCount),
            remainingWorkSafetyMarginSeconds: BufferPolicy.remainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: false
        )
    }

    private func normalModeRequiredStartSampleCount(for chunkCount: Int) -> Int {
        let seconds = chunkCount == 1
            ? BufferPolicy.singleChunkStartBufferedSeconds
            : BufferPolicy.multiChunkMinimumRunwaySeconds
        return Int(playbackFormat.sampleRate * seconds)
    }

    private func fastModeRequiredStartSampleCount(for chunkCount: Int) -> Int {
        let seconds = chunkCount == 1
            ? BufferPolicy.fastModeSingleChunkStartBufferedSeconds
            : BufferPolicy.fastModeMultiChunkMinimumRunwaySeconds
        return Int(playbackFormat.sampleRate * seconds)
    }

    private func normalModeBufferedSampleCount(
        for chunkCount: Int,
        remainingEstimatedSamples: Int,
        requiredStartSamples: Int,
        minimumCoverageSeconds: Double,
        realtimeFactor: Double,
        remainingWorkSafetyMarginSeconds: Double,
        allowFullRemainingDeficit: Bool
    ) -> Int {
        let minimumCoverageSamples = Int(playbackFormat.sampleRate * minimumCoverageSeconds)
        if remainingEstimatedSamples <= minimumCoverageSamples {
            return max(requiredStartSamples, remainingEstimatedSamples)
        }

        let deficitFactor = max(0, (1.0 / realtimeFactor) - 1.0)
        let remainingEstimatedSeconds = Double(remainingEstimatedSamples) / playbackFormat.sampleRate
        let uncappedRequiredDeficitSeconds = (remainingEstimatedSeconds * deficitFactor)
            + remainingWorkSafetyMarginSeconds
        let requiredDeficitSeconds: Double
        if allowFullRemainingDeficit {
            requiredDeficitSeconds = min(remainingEstimatedSeconds, uncappedRequiredDeficitSeconds)
        } else if chunkCount > BufferPolicy.ultraLongFormChunkThreshold,
                  uncappedRequiredDeficitSeconds >= remainingEstimatedSeconds {
            requiredDeficitSeconds = remainingEstimatedSeconds
        } else {
            requiredDeficitSeconds = min(
                maximumDeterministicRunwaySeconds(for: chunkCount),
                uncappedRequiredDeficitSeconds
            )
        }
        let deterministicRunwaySamples = Int(requiredDeficitSeconds * playbackFormat.sampleRate)

        return max(
            requiredStartSamples,
            minimumCoverageSamples,
            deterministicRunwaySamples
        )
    }

    private func fastModeMinimumCoverageSeconds(for chunkCount: Int) -> Double {
        switch chunkCount {
        case (BufferPolicy.ultraLongFormChunkThreshold + 1)...:
            return BufferPolicy.fastModeUltraLongFormMinimumCoverageSeconds
        case (BufferPolicy.longFormChunkThreshold + 1)...:
            return BufferPolicy.fastModeLongFormMinimumCoverageSeconds
        case 1:
            return BufferPolicy.fastModeSingleChunkMinimumCoverageSeconds
        default:
            return BufferPolicy.fastModeMinimumCoverageSeconds
        }
    }

    private func minimumCompletedFastModeSegmentLead(for chunkCount: Int) -> Int {
        switch chunkCount {
        case (BufferPolicy.ultraLongFormChunkThreshold + 1)...:
            return 3
        case (BufferPolicy.longFormChunkThreshold + 1)...:
            return 2
        default:
            return 1
        }
    }

    private func backgroundRealtimeFactor(for chunkCount: Int) -> Double {
        switch chunkCount {
        case (BufferPolicy.ultraLongFormChunkThreshold + 1)...:
            return BufferPolicy.ultraLongFormBackgroundRealtimeFactor
        case (BufferPolicy.longFormChunkThreshold + 1)...:
            return BufferPolicy.longFormBackgroundRealtimeFactor
        default:
            return BufferPolicy.conservativeBackgroundRealtimeFactor
        }
    }

    private func foregroundRealtimeFactor(for chunkCount: Int) -> Double {
        switch chunkCount {
        case (BufferPolicy.ultraLongFormChunkThreshold + 1)...:
            return BufferPolicy.ultraLongFormForegroundRealtimeFactor
        case (BufferPolicy.longFormChunkThreshold + 1)...:
            return BufferPolicy.longFormForegroundRealtimeFactor
        default:
            return BufferPolicy.conservativeForegroundRealtimeFactor
        }
    }

    private func maximumDeterministicRunwaySeconds(for chunkCount: Int) -> Double {
        BufferPolicy.maximumBaseDeterministicRunwaySeconds
    }

    private static func log(_ message: String) {
        NSLog("[TTSPlaybackCoordinator] %@", message)
    }
}
