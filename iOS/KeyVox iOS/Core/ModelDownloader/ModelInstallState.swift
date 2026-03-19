import Foundation

enum ModelInstallPhase: Equatable {
    case downloadingAssets
    case resumingInstall
    case movingFiles
    case verifyingGGML
    case verifyingCoreMLArchive
    case extractingCoreML
    case validatingCoreMLBundle
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
        case .verifyingGGML:
            return "Verifying GGML model"
        case .verifyingCoreMLArchive:
            return "Verifying Core ML archive"
        case .extractingCoreML:
            return "Extracting Core ML bundle"
        case .validatingCoreMLBundle:
            return "Validating Core ML bundle"
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
            return "Model: not installed"
        case .downloading(let progress, let phase),
             .installing(let progress, let phase):
            return "Model: \(phase.statusText) \(Int(progress * 100))%"
        case .ready:
            return "Model: ready"
        case .failed(let message):
            return "Model: failed (\(message))"
        }
    }
}
