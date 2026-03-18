import Foundation

@MainActor
final class KeyVoxURLRouter {
    private let transcriptionManager: TranscriptionManager

    init(transcriptionManager: TranscriptionManager) {
        self.transcriptionManager = transcriptionManager
    }

    func route(for url: URL) -> KeyVoxURLRoute? {
        KeyVoxURLRoute(url: url)
    }

    func handle(route: KeyVoxURLRoute, shouldPresentReturnToHost: Bool = true) {
        switch route {
        case .startRecording:
            transcriptionManager.handleStartRecordingCommand(isFromURL: shouldPresentReturnToHost)
        case .stopRecording:
            transcriptionManager.handleStopRecordingCommand()
        }
    }

    func handle(url: URL) {
        guard let route = route(for: url) else {
            #if DEBUG
            print("Ignoring unsupported KeyVox URL: \(url.absoluteString)")
            #endif
            return
        }

        handle(route: route)
    }
}
