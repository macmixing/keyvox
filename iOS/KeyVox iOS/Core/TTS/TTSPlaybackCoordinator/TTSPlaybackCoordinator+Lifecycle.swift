import AVFoundation
import Foundation
import KeyVoxTTS

extension TTSPlaybackCoordinator {
    func restoreReplayablePlayback(samples: [Float]) {
        replayablePlaybackSamples = samples
    }

    func restorePausedReplay(samples: [Float], pausedSampleOffset: Int) {
        let clampedPausedSampleOffset = min(max(0, pausedSampleOffset), max(0, samples.count - 1))

        replayablePlaybackSamples = samples
        activePlaybackSamples = samples
        totalEstimatedPlaybackSampleCount = samples.count
        totalScheduledSampleCount = samples.count
        queuedBufferCount = 0
        queuedSampleCount = 0
        isFinishing = false
        didStartPlayback = true
        isPaused = true
        isReplayingCachedAudio = true
        replayStartSampleOffset = 0
        replayPausedSampleOffset = clampedPausedSampleOffset
        isFastModeBackgroundSafeState = false
        stopPlaybackProgressTimer()
        emitPlaybackProgress()
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

    func play(_ stream: AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>, fastModeEnabled: Bool = false) {
        stop(emitCallback: false)
        Self.log("Playback requested. fastMode=\(fastModeEnabled)")
        playbackSessionID = UUID()

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
        isFastModeBackgroundSafeState = false
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
                    self.replayablePlaybackSamples = self.activePlaybackSamples
                    Self.log("Playback stream finished. queuedBuffers=\(self.queuedBufferCount) queuedSamples=\(self.queuedSampleCount)")
                    self.onReplayablePlaybackReady?()
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
            playbackSessionID = UUID()
            queuedBufferCount = 0
            queuedSampleCount = 0
            isFinishing = false
            totalScheduledSampleCount = 0
            if playerNode.isPlaying {
                playerNode.stop()
            }
            audioEngine.stop()
            deactivateAudioSessionIfNeeded()
        } else {
            playerNode.pause()
        }
        isPaused = true
        cancelScheduledMeterUpdates()
        stopPlaybackProgressTimer()
        emitPlaybackProgress()
        Self.log("Playback paused.")
        notifyFastModeBackgroundSafetyChanged()
        onPlaybackPaused?()
    }

    func resume() {
        guard canResumePlayback else { return }
        if isReplayingCachedAudio,
           let pausedReplaySampleOffset = replayPausedSampleOffsetSnapshot() {
            replayLastPlayback(startingAtSample: pausedReplaySampleOffset, shouldAutoplay: true)
            return
        }
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

    func replayLastPlayback(startingAtSample startSampleOffset: Int = 0, shouldAutoplay: Bool = true) {
        guard !replayablePlaybackSamples.isEmpty else { return }

        stop(emitCallback: false)
        let safeStartSampleOffset = min(max(0, startSampleOffset), max(0, replayablePlaybackSamples.count - 1))
        Self.log(
            "Replaying cached playback samples=\(replayablePlaybackSamples.count) startOffset=\(safeStartSampleOffset) autoplay=\(shouldAutoplay)"
        )
        playbackSessionID = UUID()

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
        isPaused = !shouldAutoplay
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
        replayPausedSampleOffset = shouldAutoplay ? 0 : safeStartSampleOffset
        isFastModeBackgroundSafeState = false

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
        if shouldAutoplay {
            playerNode.play()
            startPlaybackProgressTimer()
        }
        emitPlaybackProgress()
        if shouldAutoplay {
            onPlaybackStarted?()
        } else {
            onPlaybackPaused?()
        }
    }

    func stop(emitCallback: Bool) {
        let hadPlayback = playbackTask != nil || playerNode.isPlaying || queuedBufferCount > 0
        playbackSessionID = UUID()

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
        isFastModeBackgroundSafeState = false

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

    func configureAudioSession() throws {
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

    func finishIfPossible() {
        guard isFinishing, queuedBufferCount == 0, pendingStartBuffers.isEmpty else { return }

        playbackTask = nil
        activePlaybackSamples = []
        isPaused = false
        isReplayingCachedAudio = false
        replayStartSampleOffset = 0
        replayPausedSampleOffset = 0
        isFastModeBackgroundSafeState = false
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

    func deactivateAudioSessionIfNeeded() {
        guard audioSessionMode == .playback else {
            Self.log("Preserving active audio session after playback finish.")
            return
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func handleFailure(_ error: Error) {
        stop(emitCallback: false)
        onPlaybackFailed?(error)
    }
}
