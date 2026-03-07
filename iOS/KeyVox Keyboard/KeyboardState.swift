import UIKit

enum KeyboardState: Equatable {
    case idle
    case waitingForApp
    case recording
    case transcribing

    var statusText: String {
        switch self {
        case .idle:
            return "Ready"
        case .waitingForApp:
            return "Opening app..."
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        }
    }

    var micSymbolName: String {
        switch self {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .waitingForApp, .transcribing:
            return "hourglass"
        }
    }

    var isMicEnabled: Bool {
        switch self {
        case .idle, .recording:
            return true
        case .waitingForApp, .transcribing:
            return false
        }
    }

    var micBackgroundColor: UIColor {
        switch self {
        case .idle:
            return KeyboardStyle.idleMicColor
        case .recording:
            return KeyboardStyle.recordingMicColor
        case .waitingForApp, .transcribing:
            return KeyboardStyle.pendingMicColor
        }
    }
}
