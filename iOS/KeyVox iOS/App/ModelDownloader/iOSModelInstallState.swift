import Foundation

enum iOSModelInstallState: Equatable {
    case notInstalled
    case downloading(progress: Double)
    case installing
    case ready
    case failed(message: String)
}
