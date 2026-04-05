import Foundation

nonisolated enum KeyVoxURLRoute: Equatable, Sendable {
    case startRecording
    case stopRecording
    case startTTS

    init?(url: URL) {
        guard url.scheme?.lowercased() == "keyvoxios" else { return nil }
        guard let host = url.host?.lowercased() else { return nil }

        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        switch host {
        case "record":
            switch normalizedPath {
            case "start":
                self = .startRecording
            case "stop":
                self = .stopRecording
            default:
                return nil
            }
        case "tts":
            switch normalizedPath {
            case "start":
                self = .startTTS
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
