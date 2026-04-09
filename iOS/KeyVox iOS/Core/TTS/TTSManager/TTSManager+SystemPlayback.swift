import AVFoundation
import Foundation

extension TTSManager {
    private var shouldExposeFinishedReplaySystemPlayback: Bool {
        state == .finished && hasReplayablePlayback && lastReplayableRequest != nil
    }

    func configureSystemPlaybackController() {
        systemPlaybackController?.onPlay = { [weak self] in
            self?.handleSystemPlayCommand()
        }
        systemPlaybackController?.onPause = { [weak self] in
            self?.handleSystemPauseCommand()
        }
        systemPlaybackController?.onTogglePlayPause = { [weak self] in
            self?.handleSystemTogglePlayPauseCommand()
        }
        systemPlaybackController?.onSeekToTime = { [weak self] time in
            self?.handleSystemSeekCommand(time)
        }
        refreshSystemPlaybackControls()
    }

    func refreshSystemPlaybackControls() {
        guard let systemPlaybackController else { return }
        guard state == .playing || shouldExposeFinishedReplaySystemPlayback else {
            Self.log("System playback controls cleared because state=\(state.rawValue)")
            systemPlaybackController.clear()
            return
        }

        let isReplayTransport =
            isReplayingCachedPlayback
            || pausedReplaySampleOffset != nil
            || shouldExposeFinishedReplaySystemPlayback
        guard let displayText = currentPlaybackDisplayText,
              displayText.isEmpty == false else {
            Self.log("System playback controls cleared because no playback display text was available.")
            systemPlaybackController.clear()
            return
        }

        let elapsedSeconds = currentSystemPlaybackElapsedSeconds(isReplayTransport: isReplayTransport)
        let durationSeconds = isReplayTransport ? currentSystemReplayDurationSeconds : nil
        Self.log(
            "Refreshing system playback controls replay=\(isReplayTransport) paused=\(isPlaybackPaused) elapsed=\(String(format: "%.2f", elapsedSeconds)) duration=\(durationSeconds.map { String(format: "%.2f", $0) } ?? "nil")"
        )
        systemPlaybackController.update(
            displayText: displayText,
            voiceName: currentSystemPlaybackVoiceName,
            isPlaying: state == .playing && isPlaybackPaused == false,
            isReplay: isReplayTransport,
            elapsedSeconds: elapsedSeconds,
            durationSeconds: durationSeconds
        )
    }

    private var currentSystemPlaybackVoiceName: String? {
        let voiceID = activeRequest?.voiceID ?? lastReplayableRequest?.voiceID
        guard let voiceID,
              let voice = AppSettingsStore.TTSVoice(rawValue: voiceID) else {
            return nil
        }
        return voice.displayName
    }

    private func handleSystemPlayCommand() {
        Self.log(
            "Handling system play command state=\(state.rawValue) paused=\(isPlaybackPaused) replaying=\(isReplayingCachedPlayback) pausedReplayOffset=\(pausedReplaySampleOffset.map(String.init) ?? "nil")"
        )
        if isPlaybackPaused {
            resumePlayback()
            return
        }

        guard state != .playing, hasReplayablePlayback else { return }
        replayLastPlayback()
    }

    private func handleSystemPauseCommand() {
        Self.log(
            "Handling system pause command state=\(state.rawValue) paused=\(isPlaybackPaused) replaying=\(isReplayingCachedPlayback)"
        )
        guard state == .playing, isPlaybackPaused == false else { return }
        pausePlayback()
    }

    private func handleSystemTogglePlayPauseCommand() {
        Self.log(
            "Handling system togglePlayPause command state=\(state.rawValue) paused=\(isPlaybackPaused) replaying=\(isReplayingCachedPlayback)"
        )
        if state == .playing {
            if isPlaybackPaused {
                handleSystemPlayCommand()
            } else {
                handleSystemPauseCommand()
            }
            return
        }

        handleSystemPlayCommand()
    }

    private func handleSystemSeekCommand(_ time: TimeInterval) {
        let isReplayTransport = isReplayingCachedPlayback || pausedReplaySampleOffset != nil
        let replayDurationSeconds = currentSystemReplayDurationSeconds
        guard isReplayTransport, replayDurationSeconds > 0 else { return }

        let progress = min(max(0, time / replayDurationSeconds), 1)
        Self.log(
            "Handling system seek command time=\(String(format: "%.2f", time)) progress=\(String(format: "%.3f", progress)) paused=\(isPlaybackPaused) replaying=\(isReplayingCachedPlayback) pausedReplayOffset=\(pausedReplaySampleOffset.map(String.init) ?? "nil")"
        )
        seekReplay(toProgress: progress)
        refreshSystemPlaybackControls()
    }

    private var currentSystemReplayDurationSeconds: Double {
        let coordinatorDuration = replayDurationSeconds
        guard coordinatorDuration > 0 else {
            let sampleCount = playbackCoordinator.replayablePlaybackSampleCount
            guard sampleCount > 0 else { return 0 }
            return Double(sampleCount) / playbackCoordinator.playbackFormat.sampleRate
        }
        return coordinatorDuration
    }

    private func currentSystemPlaybackElapsedSeconds(isReplayTransport: Bool) -> Double {
        let coordinatorElapsed = playbackCoordinator.currentPlaybackSeconds
        guard isReplayTransport else { return coordinatorElapsed }
        guard shouldExposeFinishedReplaySystemPlayback == false else { return 0 }
        guard isPlaybackPaused, let pausedReplaySampleOffset else { return coordinatorElapsed }
        guard coordinatorElapsed == 0 else { return coordinatorElapsed }

        let duration = currentSystemReplayDurationSeconds
        guard duration > 0 else { return coordinatorElapsed }

        let sampleOffsetSeconds = Double(pausedReplaySampleOffset) / playbackCoordinator.playbackFormat.sampleRate
        let progressSeconds = min(max(0, playbackProgress * duration), duration)
        return max(sampleOffsetSeconds, progressSeconds)
    }
}
