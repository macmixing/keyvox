import Foundation

final class ComputeModeController: @unchecked Sendable {
    private let lock = NSLock()
    private var preferredMode: KeyVoxTTSComputeMode = .foreground

    func setMode(_ mode: KeyVoxTTSComputeMode) {
        lock.lock()
        preferredMode = mode
        lock.unlock()
    }

    func mode() -> KeyVoxTTSComputeMode {
        lock.lock()
        let mode = preferredMode
        lock.unlock()
        return mode
    }
}

extension KeyVoxTTSComputeMode {
    var logName: String {
        switch self {
        case .foreground:
            return "foreground"
        case .backgroundSafe:
            return "backgroundSafe"
        }
    }
}
