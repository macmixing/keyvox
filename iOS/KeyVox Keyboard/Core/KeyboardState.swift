import UIKit

enum KeyboardState: Equatable {
    case idle
    case waitingForApp
    /// The keyboard is switching the microphone on for a dictation it records itself.
    case startingDictation
    case dictationStartFailed
    case preparingPlayback
    case recording
    case transcribing
    case speaking
    case pausedSpeaking

    var indicatorPhase: AudioIndicatorPhase {
        switch self {
        case .idle, .dictationStartFailed:
            return .idle
        case .waitingForApp:
            return .waiting
        case .startingDictation:
            return .starting
        case .preparingPlayback:
            return .waiting
        case .recording:
            return .listening
        case .transcribing:
            return .processing
        case .speaking, .pausedSpeaking:
            return .idle
        }
    }

    var isIndicatorEnabled: Bool {
        switch self {
        case .idle, .recording, .transcribing, .speaking, .pausedSpeaking:
            return true
        case .waitingForApp, .startingDictation, .dictationStartFailed, .preparingPlayback:
            return false
        }
    }

    var isTTSPlaybackActive: Bool {
        switch self {
        case .speaking, .pausedSpeaking:
            return true
        case .idle, .waitingForApp, .startingDictation, .dictationStartFailed, .preparingPlayback, .recording, .transcribing:
            return false
        }
    }

    var showsCancelButton: Bool {
        switch self {
        case .idle, .startingDictation, .dictationStartFailed:
            return false
        case .waitingForApp, .recording, .transcribing:
            return true
        case .preparingPlayback:
            return false
        case .speaking, .pausedSpeaking:
            return true
        }
    }
}
