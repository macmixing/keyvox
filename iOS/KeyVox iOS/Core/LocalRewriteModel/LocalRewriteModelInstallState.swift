import Foundation

enum LocalRewriteModelInstallState: Equatable {
    case notInstalled
    case downloading(progress: Double)
    case installing(progress: Double)
    case ready
    case failed(message: String)
}
