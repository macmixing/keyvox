import AVFoundation
import Foundation
import UIKit

extension TTSManager {
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

        let effectiveShowPreparationView = TTSManagerPolicy.shouldShowPreparationView(
            requested: showPreparationView,
            fastModeEnabled: settingsStore.fastPlaybackModeEnabled,
            sourceSurface: normalizedRequest.sourceSurface
        )

        await startPlayback(normalizedRequest, showPreparationView: effectiveShowPreparationView)
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
        playbackCoordinator.setPreparationCompletionDelay(
            enabled: showPreparationView && settingsStore.fastPlaybackModeEnabled == false
        )
        beginBackgroundTaskIfNeeded()
        await engine.prepareForForegroundSynthesis()
        playbackCoordinator.prepareForForegroundPlayback()
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

    func seekReplay(toProgress progress: Double) {
        guard hasReplayablePlayback else { return }

        let clampedProgress = min(max(0, progress), 1)
        let sampleOffset = Int(Double(playbackCoordinator.replayablePlaybackSampleCount) * clampedProgress)
        let shouldAutoplay = isPlaybackPaused == false

        if let lastReplayableRequest {
            activeRequest = lastReplayableRequest
        }
        hasStartedPlaybackForActiveRequest = true
        didEmitPreparationCompletionForActiveRequest = true
        lastErrorMessage = nil
        resetPlaybackPreparationState()
        isPlaybackPreparationViewPresented = false
        beginBackgroundTaskIfNeeded()
        playbackCoordinator.replayLastPlayback(
            startingAtSample: sampleOffset,
            shouldAutoplay: shouldAutoplay
        )
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
}
