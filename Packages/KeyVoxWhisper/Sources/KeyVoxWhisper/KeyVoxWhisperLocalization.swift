import Foundation

/// Finds this package's translations. Hosts outside Apple platforms show the English text written in code.
enum KeyVoxWhisperLocalization {
    static var bundle: Bundle {
        #if canImport(Darwin)
        return .module
        #else
        return .main
        #endif
    }
}
