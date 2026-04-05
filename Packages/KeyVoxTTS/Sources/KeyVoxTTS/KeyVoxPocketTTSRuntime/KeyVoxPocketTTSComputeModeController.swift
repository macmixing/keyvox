import Foundation

actor ComputeModeController {
    private var preferredMode: KeyVoxTTSComputeMode = .foreground

    func setMode(_ mode: KeyVoxTTSComputeMode) {
        preferredMode = mode
    }

    func mode() -> KeyVoxTTSComputeMode {
        preferredMode
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
