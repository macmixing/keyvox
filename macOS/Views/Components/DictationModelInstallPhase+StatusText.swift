import Foundation

extension DictationModelInstallPhase {
    var statusText: String {
        switch self {
        case .downloading:
            return "Downloading"
        case .verifying:
            return "Verifying"
        case .installing:
            return "Installing"
        case .warmingUp:
            return "Warming up"
        }
    }
}
