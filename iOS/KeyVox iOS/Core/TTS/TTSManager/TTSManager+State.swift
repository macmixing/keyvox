import Foundation
import KeyVoxTTS

extension TTSManager {
    private enum WarningCopy {
        static let emptyClipboard = "Copy something first."
    }

    func showEmptyClipboardWarning() {
        warningMessage = WarningCopy.emptyClipboard
        appHaptics.warning()
    }

    func clearWarningMessage() {
        warningMessage = nil
    }

    func presentPlaybackPreparationView() {
        shouldPersistPlaybackPreparationViewUntilBackground = true
        resetPlaybackPreparationState()
        isPlaybackPreparationViewPresented = true
    }

    func dismissPlaybackPreparationView() {
        shouldPersistPlaybackPreparationViewUntilBackground = false
        isPlaybackPreparationViewPresented = false
        resetPlaybackPreparationState()
    }

    func finishPlayback() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let completedRequestID = activeRequest?.id
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
            self.updateState(.finished)
            await self.onWillTeardownPlayback?()
            KeyVoxIPCBridge.markRecentTTSPlayback()
            if let completedRequestID {
                self.benchmarkRecorder.markFinished(for: completedRequestID)
            }
            self.clearActiveRequest(
                clearSharedTransportState: false,
                preserveFinishedSystemPlayback: self.hasReplayablePlayback
            )
        }
    }

    func handleReplayablePlaybackReady() {
        guard let activeRequest else { return }
        lastReplayableRequest = activeRequest
        hasReplayablePlayback = playbackCoordinator.hasReplayablePlayback
        persistReplayablePlaybackIfNeeded(for: activeRequest)
        benchmarkRecorder.markReplayReady(
            for: activeRequest.id,
            totalSampleCount: playbackCoordinator.replayablePlaybackSampleCount
        )
        Self.log("Replayable playback became available for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
    }

    func handleError(_ message: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let failedRequestID = activeRequest?.id
            if let activeRequest {
                Self.log("Playback failed for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID) error=\(message)")
            } else {
                Self.log("Playback failed with no active request. error=\(message)")
            }
            self.warningMessage = nil
            self.lastErrorMessage = message
            self.isPlaybackPaused = false
            self.pausedReplaySampleOffset = nil
            self.dismissPlaybackPreparationView()
            self.updateState(.error)
            await self.onWillTeardownPlayback?()
            KeyVoxIPCBridge.markRecentTTSPlayback()
            self.keyboardBridge.publishTTSFailed(message: message)
            if let failedRequestID {
                self.benchmarkRecorder.markFailed(for: failedRequestID, message: message)
            }
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

        refreshSystemPlaybackControls()
    }

    func clearActiveRequest(
        clearPublishedState: Bool = true,
        clearSharedTransportState: Bool = true,
        preserveFinishedSystemPlayback: Bool = false
    ) {
        fastModeBackgroundSafetyTask?.cancel()
        fastModeBackgroundSafetyTask = nil
        activeRequest = nil
        hasStartedPlaybackForActiveRequest = false
        didEmitPreparationCompletionForActiveRequest = false
        shouldConsumeFreeSpeakOnPlaybackStart = false
        isPlaybackPaused = false
        isReplayingCachedPlayback = false
        pausedReplaySampleOffset = nil
        hasReplayablePlayback = playbackCoordinator.hasReplayablePlayback
        playbackProgress = 0
        if clearSharedTransportState {
            keyboardBridge.publishTTSPlaybackProgress(playbackProgress)
        }
        fastModeBackgroundSafetyProgress = 0
        isFastModeBackgroundSafe = false
        KeyVoxIPCBridge.clearTTSRequest()
        let shouldPreservePlaybackPreparationView =
            shouldPersistPlaybackPreparationViewUntilBackground
            && playbackPreparationPhase == .readyToReturn
        if shouldPreservePlaybackPreparationView {
            Self.log("Preserving playback preparation view until background transition.")
        } else {
            dismissPlaybackPreparationView()
        }
        playbackCoordinator.setPreparationCompletionDelay(enabled: false)
        endBackgroundTaskIfNeeded()

        if clearPublishedState && preserveFinishedSystemPlayback == false {
            state = .idle
            updateIdleSleepPrevention()
            if clearSharedTransportState {
                KeyVoxIPCBridge.clearTTSState()
            }
        }

        if preserveFinishedSystemPlayback {
            state = .finished
            updateIdleSleepPrevention()
        } else if clearPublishedState == false, clearSharedTransportState {
            KeyVoxIPCBridge.clearTTSState()
        }

        refreshSystemPlaybackControls()
    }

    func handlePlaybackStarted() {
        if let activeRequest {
            Self.log("Playback started for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
            benchmarkRecorder.markPlaybackStarted(for: activeRequest.id)
        }
        if shouldConsumeFreeSpeakOnPlaybackStart {
            purchaseGate.consumeFreeTTSSpeakIfNeeded()
            onNewGenerationPlaybackStarted()
            shouldConsumeFreeSpeakOnPlaybackStart = false
        }
        warningMessage = nil
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
        refreshSystemPlaybackControls()
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
        refreshSystemPlaybackControls()
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

    func handleFastModeBackgroundSafetyChanged(progress: Double, isSafe: Bool) {
        fastModeBackgroundSafetyProgress = progress

        if isSafe == false {
            fastModeBackgroundSafetyTask?.cancel()
            fastModeBackgroundSafetyTask = nil
            isFastModeBackgroundSafe = false
            return
        }

        if let activeRequest {
            benchmarkRecorder.markBackgroundReady(for: activeRequest.id)
        }

        guard isFastModeBackgroundSafe == false else { return }
        guard fastModeBackgroundSafetyTask == nil else { return }

        fastModeBackgroundSafetyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self else { return }
            guard Task.isCancelled == false else { return }

            self.isFastModeBackgroundSafe = true
            self.appHaptics.medium()
            if let activeRequest = self.activeRequest {
                self.benchmarkRecorder.markBackgroundStable(for: activeRequest.id)
            }
            self.fastModeBackgroundSafetyTask = nil
        }
    }

    func handlePlaybackFrame(_ frame: KeyVoxTTSAudioFrame) {
        guard let activeRequest else { return }
        benchmarkRecorder.recordFrame(frame, for: activeRequest.id)
    }

    func handlePlaybackCancelled() {
        if let activeRequest {
            benchmarkRecorder.markCancelled(for: activeRequest.id)
        }
        clearActiveRequest()
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
        refreshSystemPlaybackControls()
    }

    func persistReplayablePlaybackIfNeeded(for request: KeyVoxTTSRequest) {
        guard let samples = playbackCoordinator.replayablePlaybackSamplesSnapshot() else { return }
        replayCache.save(request: request, samples: samples, pausedSampleOffset: nil)
    }
}
