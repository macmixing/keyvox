import Foundation
import UIKit

// Non-visual transport state and accessibility behavior for the keyboard logo control
// stays separate from the proprietary logo-bar rendering implementation.

extension KeyboardLogoBarView {
    func applyKeyboardState(_ state: KeyboardState) {
        let wasShowingRecordingStartFailure = keyboardState == .dictationStartFailed
        let previousTransportSymbolName = transportSymbolName
        keyboardState = state
        if state.isTTSPlaybackActive == false {
            playbackProgress = 0
        }
        let nextTransportSymbolName = transportSymbolName

        if state == .dictationStartFailed, wasShowingRecordingStartFailure == false {
            updateAccessibility()
            animateRecordingStartFailure()
            updateLayerFrames()
            return
        }

        if state != .dictationStartFailed, wasShowingRecordingStartFailure {
            updateAccessibility()
            animateRecordingStartFailureReturn()
            // The failure left the bars at idle; a state that moves on straight to recording or
            // transcribing still needs its bars.
            applyIndicatorPhase(state.indicatorPhase)
            updateLayerFrames()
            return
        }

        if indicatorPhase != state.indicatorPhase {
            applyIndicatorPhase(state.indicatorPhase)
            return
        }

        updateAccessibility()
        guard previousTransportSymbolName != nextTransportSymbolName else { return }

        if previousTransportSymbolName != nil, nextTransportSymbolName == nil {
            animateTransportReturnToMicrophone()
            return
        }

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
        case .dictationStartFailed:
            return nil
        case .idle, .waitingForApp, .preparingPlayback, .recording, .transcribing:
            return nil
        }
    }

    func updateAccessibility() {
        switch keyboardState {
        case .idle:
            accessibilityLabel = String(localized: "Start recording", comment: "VoiceOver label for the keyboard's dictation button when it is ready to record.")
            accessibilityValue = String(localized: "Ready", comment: "VoiceOver value for the keyboard's dictation button when it is ready to record.")
            isEnabled = true
        case .waitingForApp:
            accessibilityLabel = String(localized: "Opening app", comment: "VoiceOver label for the keyboard's dictation button while the KeyVox app is opening.")
            accessibilityValue = String(localized: "Waiting", comment: "VoiceOver value for the keyboard's dictation button while the KeyVox app is opening.")
            isEnabled = false
        case .dictationStartFailed:
            accessibilityLabel = String(localized: "Dictation couldn't start", comment: "VoiceOver label for the keyboard's dictation button after dictation failed to start.")
            accessibilityValue = nil
            isEnabled = false
        case .recording:
            accessibilityLabel = String(localized: "Stop recording and transcribe", comment: "VoiceOver label for the keyboard's dictation button while recording.")
            accessibilityValue = String(localized: "Recording", comment: "VoiceOver value for the keyboard's dictation button while recording (the state, not the verb).")
            isEnabled = true
        case .transcribing:
            accessibilityLabel = String(localized: "Transcribing", comment: "VoiceOver label and value for the keyboard's dictation button while speech is being turned into text.")
            accessibilityValue = String(localized: "Transcribing", comment: "VoiceOver label and value for the keyboard's dictation button while speech is being turned into text.")
            isEnabled = false
        case .preparingPlayback:
            accessibilityLabel = String(localized: "Opening app", comment: "VoiceOver label for the keyboard's dictation button while the KeyVox app is opening.")
            accessibilityValue = String(localized: "Waiting", comment: "VoiceOver value for the keyboard's dictation button while the KeyVox app is opening.")
            isEnabled = false
        case .speaking:
            accessibilityLabel = String(localized: "Pause playback", comment: "VoiceOver label for the keyboard's button while copied text is being read aloud.")
            accessibilityValue = String(localized: "Speaking", comment: "VoiceOver value for the keyboard's button while copied text is being read aloud.")
            isEnabled = true
        case .pausedSpeaking:
            accessibilityLabel = String(localized: "Resume playback", comment: "VoiceOver label for the keyboard's button while reading aloud is paused.")
            accessibilityValue = String(localized: "Paused", comment: "VoiceOver value for the keyboard's button while reading aloud is paused.")
            isEnabled = true
        }
    }
}
