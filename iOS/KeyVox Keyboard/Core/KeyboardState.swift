import UIKit

enum KeyboardState: Equatable {
    case idle
    case waitingForApp
    case recording
    case transcribing
    case speaking

    var indicatorPhase: AudioIndicatorPhase {
        switch self {
        case .idle:
            return .idle
        case .waitingForApp:
            return .waiting
        case .recording:
            return .listening
        case .transcribing:
            return .processing
        case .speaking:
            return .speaking
        }
    }

    var isIndicatorEnabled: Bool {
        switch self {
        case .idle, .recording, .transcribing, .speaking:
            return true
        case .waitingForApp:
            return false
        }
    }

    var showsCancelButton: Bool {
        switch self {
        case .idle:
            return false
        case .waitingForApp, .recording, .transcribing, .speaking:
            return true
        }
    }
}
