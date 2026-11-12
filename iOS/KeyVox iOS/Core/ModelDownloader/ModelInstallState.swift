import Foundation

enum ModelInstallPhase: Equatable {
    case downloadingAssets
    case resumingInstall
    case movingFiles
    case verifyingArtifacts
    case extractingModelAssets
    case validatingInstalledArtifacts
    case writingManifest
    case warmingModel

    var statusText: String {
        switch self {
        case .downloadingAssets:
            return String(localized: "Downloading model assets", comment: "Dictation model install progress step.")
        case .resumingInstall:
            return String(localized: "Preparing model install", comment: "Dictation model install progress step.")
        case .movingFiles:
            return String(localized: "Moving downloaded files", comment: "Dictation model install progress step.")
        case .verifyingArtifacts:
            return String(localized: "Verifying model assets", comment: "Dictation model install progress step.")
        case .extractingModelAssets:
            return String(localized: "Extracting model assets", comment: "Dictation model install progress step.")
        case .validatingInstalledArtifacts:
            return String(localized: "Validating installed model", comment: "Dictation model install progress step.")
        case .writingManifest:
            return String(localized: "Finalizing install", comment: "Dictation model install progress step.")
        case .warmingModel:
            return String(localized: "Warming model", comment: "Dictation model install progress step: loading the model so it is ready to use.")
        }
    }
}

enum ModelInstallState: Equatable {
    case notInstalled
    case downloading(progress: Double, phase: ModelInstallPhase)
    case installing(progress: Double, phase: ModelInstallPhase)
    case ready
    case failed(message: String)

    var actionText: String? {
        switch self {
        case .downloading:
            return String(localized: "Downloading...", comment: "Status text while a dictation model is downloading.")
        case .installing:
            return String(localized: "Installing...", comment: "Status text while a dictation model is installing.")
        default:
            return nil
        }
    }

    var statusText: String {
        switch self {
        case .notInstalled:
            return String(localized: "Not installed", comment: "Dictation model status when the model is not on the device.")
        case .downloading(let progress, let phase),
             .installing(let progress, let phase):
            return String(localized: "\(phase.statusText) \(progress.formatted(.percent.precision(.fractionLength(0)).rounded(rule: .down)))", comment: "Dictation model install status. The first placeholder is the current install step and the second is the percent complete.")
        case .ready:
            return String(localized: "Ready", comment: "Dictation model status when the model is installed and ready to use.")
        case .failed(let message):
            return String(localized: "Repair needed (\(message))", comment: "Dictation model status when the install is broken. The placeholder is the error message.")
        }
    }
}
