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
            return "Downloading model assets"
        case .resumingInstall:
            return "Preparing model install"
        case .movingFiles:
            return "Moving downloaded files"
        case .verifyingArtifacts:
            return "Verifying model assets"
        case .extractingModelAssets:
            return "Extracting model assets"
        case .validatingInstalledArtifacts:
            return "Validating installed model"
        case .writingManifest:
            return "Finalizing install"
        case .warmingModel:
            return "Warming model"
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
            return "Downloading..."
        case .installing:
            return "Installing..."
        default:
            return nil
        }
    }

    var statusText: String {
        switch self {
        case .notInstalled:
            return "Not installed"
        case .downloading(let progress, let phase),
             .installing(let progress, let phase):
            return "\(phase.statusText) \(Int(progress * 100))%"
        case .ready:
            return "Ready"
        case .failed(let message):
            return "Repair needed (\(message))"
        }
    }
}
