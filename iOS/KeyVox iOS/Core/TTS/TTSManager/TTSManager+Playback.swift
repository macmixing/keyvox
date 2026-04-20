import AVFoundation
import Foundation

extension TTSManager {
    func startPlaybackFromClipboard() async {
        clearWarningMessage()

        guard let text = clipboardTextProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.isEmpty == false else {
            showEmptyClipboardWarning()
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
        clearWarningMessage()

        guard let request = KeyVoxIPCBridge.readTTSRequest(),
              request.trimmedText.isEmpty == false else {
            dismissPlaybackPreparationView()
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

        let effectiveShowPreparationView = TTSManagerPolicy.shouldShowPreparationView(
            requested: showPreparationView,
            fastModeEnabled: settingsStore.fastPlaybackModeEnabled,
            sourceSurface: normalizedRequest.sourceSurface
        )

        await startPlayback(normalizedRequest, showPreparationView: effectiveShowPreparationView)
    }

    func startPlayback(_ request: KeyVoxTTSRequest, showPreparationView: Bool = false) async {
        clearWarningMessage()
        cancelScheduledRuntimeUnload(reason: "newPlayback")

        if canReplayExistingAsset(for: request) {
            Self.log(
                "Reusing replayable asset for id=\(request.id.uuidString) voice=\(request.voiceID) source=\(request.sourceSurface.rawValue) textLength=\(request.trimmedText.count)"
            )
            if isActive {
                await stopPlayback()
            }
            replayLastPlayback()
            return
        }

        if isActive {
            await stopPlayback()
        }

        Self.log(
            "Starting request id=\(request.id.uuidString) voice=\(request.voiceID) source=\(request.sourceSurface.rawValue) textLength=\(request.trimmedText.count) showPreparationView=\(showPreparationView)"
        )
        activeRequest = request
        hasStartedPlaybackForActiveRequest = false
        didEmitPreparationCompletionForActiveRequest = false
        shouldConsumeFreeSpeakOnPlaybackStart = true
        isPlaybackPaused = false
        lastErrorMessage = nil
        if showPreparationView {
            presentPlaybackPreparationView()
        } else {
            dismissPlaybackPreparationView()
        }
        playbackCoordinator.setPreparationCompletionDelay(
            enabled: showPreparationView && settingsStore.fastPlaybackModeEnabled == false
        )
        beginBackgroundTaskIfNeeded()
        await engine.prepareForForegroundSynthesis()
        playbackCoordinator.prepareForForegroundPlayback()
        isCurrentPlaybackWarmStart = engine.isPreparedForSynthesis
        Self.log(
            "Playback start runtimeWarm=\(isCurrentPlaybackWarmStart) speakTimeout=\(settingsStore.speakTimeoutTiming.rawValue)"
        )
        updateState(.preparing)

        do {
            try await engine.prepareIfNeeded()
            updateState(.generating)

            let stream = try await engine.makeAudioStream(
                for: request.trimmedText,
                voiceID: request.voiceID,
                fastModeEnabled: settingsStore.fastPlaybackModeEnabled
            )
            playbackCoordinator.play(stream, fastModeEnabled: settingsStore.fastPlaybackModeEnabled)
        } catch {
            shouldConsumeFreeSpeakOnPlaybackStart = false
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
        clearWarningMessage()

        if playbackCoordinator.canResumePlayback == false,
           let pausedReplaySampleOffset,
           hasReplayablePlayback,
           let lastReplayableRequest {
            activeRequest = lastReplayableRequest
            hasStartedPlaybackForActiveRequest = true
            didEmitPreparationCompletionForActiveRequest = true
            shouldConsumeFreeSpeakOnPlaybackStart = false
            isPlaybackPaused = false
            lastErrorMessage = nil
            dismissPlaybackPreparationView()
            beginBackgroundTaskIfNeeded()
            playbackCoordinator.replayLastPlayback(startingAtSample: pausedReplaySampleOffset)
            return
        }

        playbackCoordinator.resume()
    }

    func replayLastPlayback() {
        guard hasReplayablePlayback else { return }
        clearWarningMessage()

        if let lastReplayableRequest {
            activeRequest = lastReplayableRequest
        }
        hasStartedPlaybackForActiveRequest = false
        didEmitPreparationCompletionForActiveRequest = true
        shouldConsumeFreeSpeakOnPlaybackStart = false
        isPlaybackPaused = false
        pausedReplaySampleOffset = nil
        lastErrorMessage = nil
        dismissPlaybackPreparationView()
        beginBackgroundTaskIfNeeded()
        playbackCoordinator.replayLastPlayback()
    }

    func seekReplay(toProgress progress: Double) {
        guard hasReplayablePlayback else { return }
        clearWarningMessage()

        let clampedProgress = min(max(0, progress), 1)
        let sampleOffset = Int(Double(playbackCoordinator.replayablePlaybackSampleCount) * clampedProgress)
        let shouldAutoplay = isPlaybackPaused == false

        if let lastReplayableRequest {
            activeRequest = lastReplayableRequest
        }
        hasStartedPlaybackForActiveRequest = true
        didEmitPreparationCompletionForActiveRequest = true
        shouldConsumeFreeSpeakOnPlaybackStart = false
        isReplayingCachedPlayback = true
        playbackProgress = clampedProgress
        if shouldAutoplay {
            pausedReplaySampleOffset = nil
        } else {
            pausedReplaySampleOffset = sampleOffset
            keyboardBridge.publishTTSPaused()
        }
        keyboardBridge.publishTTSPlaybackProgress(playbackProgress)
        lastErrorMessage = nil
        dismissPlaybackPreparationView()
        if shouldAutoplay {
            beginBackgroundTaskIfNeeded()
            playbackCoordinator.replayLastPlayback(
                startingAtSample: sampleOffset,
                shouldAutoplay: true
            )
            return
        }

        if let samples = playbackCoordinator.replayablePlaybackSamplesSnapshot() {
            Self.log("Restoring paused replay position sampleOffset=\(sampleOffset)")
            playbackCoordinator.restorePausedReplay(
                samples: samples,
                pausedSampleOffset: sampleOffset
            )
            refreshSystemPlaybackControls()
            return
        }

        beginBackgroundTaskIfNeeded()
        playbackCoordinator.replayLastPlayback(
            startingAtSample: sampleOffset,
            shouldAutoplay: false
        )
    }

    func stopPlayback() async {
        clearWarningMessage()

        if let activeRequest {
            Self.log("Stop requested for id=\(activeRequest.id.uuidString) voice=\(activeRequest.voiceID)")
        } else {
            Self.log("Stop requested with no active request.")
        }
        playbackCoordinator.stop()
        scheduleRuntimeUnloadAfterPlayback(reason: .stopPlayback)
        await onWillTeardownPlayback?()
        KeyVoxIPCBridge.clearTTSRequest()
        keyboardBridge.publishTTSStopped()
        if let lastReplayableRequest {
            persistReplayablePlaybackIfNeeded(for: lastReplayableRequest)
        }
        clearActiveRequest()
    }
}
