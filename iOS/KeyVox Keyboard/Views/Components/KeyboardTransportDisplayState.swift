import UIKit

// Non-visual transport state and accessibility behavior for the keyboard logo control
// stays separate from the proprietary logo-bar rendering implementation.

extension KeyboardLogoBarView {
    func applyKeyboardState(_ state: KeyboardState) {
        let previousTransportSymbolName = transportSymbolName
        keyboardState = state
        if state.isTTSPlaybackActive == false {
            playbackProgress = 0
        }
        let nextTransportSymbolName = transportSymbolName

        if indicatorPhase != state.indicatorPhase {
            applyIndicatorPhase(state.indicatorPhase)
            return
        }

        updateAccessibility()
        guard previousTransportSymbolName != nextTransportSymbolName else { return }

        let iconSide = min(bounds.width, bounds.height) * currentCenterIconSizeRatio()
        updateCenterIconImageIfNeeded(for: CGSize(width: iconSide, height: iconSide))
        updateLayerFrames()
    }

    func applyPlaybackProgress(_ progress: CGFloat) {
        let clampedProgress = min(max(progress, 0), 1)
        let nextProgress = keyboardState.isTTSPlaybackActive ? clampedProgress : 0
        guard abs(playbackProgress - nextProgress) > 0.0001 else { return }
        playbackProgress = nextProgress
        updateLayerFrames()
    }

    func applyIndicatorPhase(_ phase: AudioIndicatorPhase) {
        guard indicatorPhase != phase else { return }
        let oldPhase = indicatorPhase
        indicatorPhase = phase
        updateAccessibility()
        handleIndicatorPhaseTransition(from: oldPhase, to: phase)
        updateLayerFrames()
    }

    func applyTimelineState(_ state: AudioIndicatorTimelineState) {
        timelineState = state
        updateLayerFrames()
    }

    var transportSymbolName: String? {
        switch keyboardState {
        case .speaking:
            return "pause.fill"
        case .pausedSpeaking:
            return "play.fill"
        case .idle, .waitingForApp, .preparingPlayback, .recording, .transcribing:
            return nil
        }
    }

    func updateAccessibility() {
        switch keyboardState {
        case .idle:
            accessibilityLabel = "Start recording"
            accessibilityValue = "Ready"
            isEnabled = true
        case .waitingForApp:
            accessibilityLabel = "Opening app"
            accessibilityValue = "Waiting"
            isEnabled = false
        case .recording:
            accessibilityLabel = "Stop recording and transcribe"
            accessibilityValue = "Recording"
            isEnabled = true
        case .transcribing:
            accessibilityLabel = "Transcribing"
            accessibilityValue = "Transcribing"
            isEnabled = false
        case .preparingPlayback:
            accessibilityLabel = "Opening app"
            accessibilityValue = "Waiting"
            isEnabled = false
        case .speaking:
            accessibilityLabel = "Pause playback"
            accessibilityValue = "Speaking"
            isEnabled = true
        case .pausedSpeaking:
            accessibilityLabel = "Resume playback"
            accessibilityValue = "Paused"
            isEnabled = true
        }
    }
}
