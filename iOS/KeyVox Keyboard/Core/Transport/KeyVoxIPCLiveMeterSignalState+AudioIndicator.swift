import Foundation

extension KeyVoxIPCLiveMeterSignalState {
    /// How the keyboard's audio indicator shows this signal state.
    var audioIndicatorSignalState: AudioIndicatorSignalState {
        switch self {
        case .dead:
            return .inactive
        case .quiet:
            return .lowActivity
        case .active:
            return .active
        }
    }
}
