import Foundation

extension TTSManager {
    func finishPlayback() {
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

    func handleReplayablePlaybackReady() {
        guard let activeRequest else { return }
        lastReplayableRequest = activeRequest
        hasReplayablePlayback = playbackCoordinator.hasReplayablePlayback
        persistReplayablePlaybackIfNeeded(for: activeRequest)
        Self.log("Replayable playback became available for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
    }

    func handleError(_ message: String) {
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

    func updateState(_ newState: KeyVoxTTSState) {
        state = newState
        updateIdleSleepPrevention()

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

    func clearActiveRequest(clearPublishedState: Bool = true) {
        activeRequest = nil
        hasStartedPlaybackForActiveRequest = false
        didEmitPreparationCompletionForActiveRequest = false
        shouldConsumeFreeSpeakOnPlaybackStart = false
        isPlaybackPaused = false
        isReplayingCachedPlayback = false
        pausedReplaySampleOffset = nil
        hasReplayablePlayback = playbackCoordinator.hasReplayablePlayback
        playbackProgress = 0
        keyboardBridge.publishTTSPlaybackProgress(playbackProgress)
        fastModeBackgroundSafetyProgress = 0
        isFastModeBackgroundSafe = false
        KeyVoxIPCBridge.clearTTSRequest()
        isPlaybackPreparationViewPresented = false
        resetPlaybackPreparationState()
        playbackCoordinator.setPreparationCompletionDelay(enabled: false)
        endBackgroundTaskIfNeeded()

        if clearPublishedState {
            state = .idle
            updateIdleSleepPrevention()
            KeyVoxIPCBridge.clearTTSState()
        }
    }

    func handlePlaybackStarted() {
        if let activeRequest {
            Self.log("Playback started for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
        }
        if shouldConsumeFreeSpeakOnPlaybackStart {
            purchaseGate.consumeFreeTTSSpeakIfNeeded()
            onNewGenerationPlaybackStarted()
            shouldConsumeFreeSpeakOnPlaybackStart = false
        }
        hasStartedPlaybackForActiveRequest = true
        isPlaybackPaused = false
        isReplayingCachedPlayback = playbackCoordinator.isReplayingCachedPlayback
        pausedReplaySampleOffset = nil
        hasReplayablePlayback = playbackCoordinator.hasReplayablePlayback
        updateState(.playing)
        if isPlaybackPreparationViewPresented {
            playbackPreparationProgress = 1
            playbackPreparationPhase = .readyToReturn
        }
    }

    func handlePreparationCompleted() {
        playbackPreparationProgress = 1
        playbackPreparationPhase = .readyToReturn
        guard didEmitPreparationCompletionForActiveRequest == false else { return }
        didEmitPreparationCompletionForActiveRequest = true
        appHaptics.success()
    }

    func handlePlaybackPaused() {
        Self.log("Playback paused.")
        isPlaybackPaused = true
        isReplayingCachedPlayback = playbackCoordinator.isReplayingCachedPlayback
        keyboardBridge.publishTTSPaused()
        updateIdleSleepPrevention()
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

    func handlePlaybackResumed() {
        Self.log("Playback resumed.")
        isPlaybackPaused = false
        isReplayingCachedPlayback = playbackCoordinator.isReplayingCachedPlayback
        pausedReplaySampleOffset = nil
        keyboardBridge.publishTTSResumed()
        updateIdleSleepPrevention()
        if let request = lastReplayableRequest ?? activeRequest,
           let samples = playbackCoordinator.replayablePlaybackSamplesSnapshot() {
            replayCache.updatePauseState(
                request: request,
                sampleCount: samples.count,
                pausedSampleOffset: nil
            )
        }
    }

    func updatePlaybackPreparationProgress(
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

    func resetPlaybackPreparationState() {
        playbackPreparationProgress = 0
        playbackPreparationPhase = .preparing
    }

    func restoreReplayablePlaybackIfNeeded() {
        guard let snapshot = replayCache.load() else {
            hasReplayablePlayback = false
            return
        }

        lastReplayableRequest = snapshot.request
        hasReplayablePlayback = true
        if let pausedSampleOffset = snapshot.pausedSampleOffset,
           pausedSampleOffset > 0,
           pausedSampleOffset < snapshot.samples.count {
            playbackCoordinator.restorePausedReplay(
                samples: snapshot.samples,
                pausedSampleOffset: pausedSampleOffset
            )
            pausedReplaySampleOffset = pausedSampleOffset
            activeRequest = snapshot.request
            hasStartedPlaybackForActiveRequest = true
            isPlaybackPaused = true
            isReplayingCachedPlayback = true
            state = .playing
            playbackProgress = playbackCoordinator.currentPlaybackProgress
            keyboardBridge.publishTTSPlaybackProgress(playbackProgress)
            keyboardBridge.publishTTSPaused()
        } else {
            playbackCoordinator.restoreReplayablePlayback(samples: snapshot.samples)
            pausedReplaySampleOffset = nil
        }
    }

    func persistReplayablePlaybackIfNeeded(for request: KeyVoxTTSRequest) {
        guard let samples = playbackCoordinator.replayablePlaybackSamplesSnapshot() else { return }
        replayCache.save(request: request, samples: samples, pausedSampleOffset: nil)
    }
}
