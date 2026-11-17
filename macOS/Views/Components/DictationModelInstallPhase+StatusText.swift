import Foundation

extension DictationModelInstallPhase {
    var statusText: String {
        switch self {
        case .downloading:
            return String(localized: "Downloading", comment: "Progress label shown beside a dictation model's download progress bar while the model downloads.")
        case .verifying:
            return String(localized: "Verifying", comment: "Progress label shown beside a dictation model's download progress bar while the downloaded model is checked.")
        case .installing:
            return String(localized: "Installing", comment: "Progress label shown beside a dictation model's download progress bar while the model installs.")
        case .warmingUp:
            return String(localized: "Warming up", comment: "Progress label shown beside a dictation model's download progress bar while the model is prepared for first use.")
        }
    }
}
