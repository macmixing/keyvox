import UIKit

enum KeyboardState: Equatable {
    case idle
    case waitingForApp
    case recording
    case transcribing

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
        }
    }

    var isIndicatorEnabled: Bool {
        switch self {
        case .idle, .recording:
            return true
        case .waitingForApp, .transcribing:
            return false
        }
    }

    var showsCancelButton: Bool {
        switch self {
        case .idle:
            return false
        case .waitingForApp, .recording, .transcribing:
            return true
        }
    }
}
