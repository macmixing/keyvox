import Foundation

nonisolated enum KeyVoxURLRoute: Equatable, Sendable {
    case startRecording
    case stopRecording

    init?(url: URL) {
        guard url.scheme?.lowercased() == "keyvoxios" else { return nil }
        guard url.host?.lowercased() == "record" else { return nil }

        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        switch normalizedPath {
        case "start":
            self = .startRecording
        case "stop":
            self = .stopRecording
        default:
            return nil
        }
    }
}
