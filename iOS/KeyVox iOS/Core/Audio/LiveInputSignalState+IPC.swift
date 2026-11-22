extension LiveInputSignalState {
    var ipcSignalState: KeyVoxIPCLiveMeterSignalState {
        switch self {
        case .dead:
            return .dead
        case .quiet:
            return .quiet
        case .active:
            return .active
        }
    }
}
