import UIKit

enum KeyboardState: Equatable {
    case idle
    case waitingForApp
    case preparingPlayback
    case recording
    case transcribing
    case speaking
    case pausedSpeaking

    var indicatorPhase: AudioIndicatorPhase {
        switch self {
        case .idle:
            return .idle
        case .waitingForApp:
            return .waiting
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
        case .waitingForApp, .preparingPlayback:
            return false
        }
    }

    var isTTSPlaybackActive: Bool {
        switch self {
        case .speaking, .pausedSpeaking:
            return true
        case .idle, .waitingForApp, .preparingPlayback, .recording, .transcribing:
            return false
        }
    }

    var showsCancelButton: Bool {
        switch self {
        case .idle:
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
