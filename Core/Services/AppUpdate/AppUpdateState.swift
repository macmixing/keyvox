import Foundation

enum AppUpdateState: Equatable {
    case idle
    case checking
    case available
    case requiresApplicationsInstall
    case downloading
    case verifyingChecksum
    case extracting
    case verifyingSignature
    case readyToInstall
    case installing
    case failed
    case completed
    case manualOnly
}
