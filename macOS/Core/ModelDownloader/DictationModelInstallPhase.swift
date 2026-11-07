import Foundation

enum DictationModelInstallPhase: Equatable, Sendable {
    case downloading
    case verifying
    case installing
    case warmingUp
}
