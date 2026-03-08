import UIKit

enum KeyboardState: Equatable {
    case idle
    case waitingForApp
    case recording
    case transcribing

    var logoVisualState: KeyboardLogoBarView.VisualState {
        switch self {
        case .idle:
            return .idle
        case .waitingForApp:
            return .waitingForApp
        case .recording:
            return .recording
        case .transcribing:
            return .transcribing
        }
    }

    var isLogoBarEnabled: Bool {
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
