import Foundation

@MainActor
final class KeyVoxURLRouter {
    private let audioModeCoordinator: AudioModeCoordinator
    private let transcriptionManager: TranscriptionManager
    private let ttsManager: TTSManager

    init(
        transcriptionManager: TranscriptionManager,
        ttsManager: TTSManager,
        audioModeCoordinator: AudioModeCoordinator
    ) {
        self.audioModeCoordinator = audioModeCoordinator
        self.transcriptionManager = transcriptionManager
        self.ttsManager = ttsManager
    }

    func route(for url: URL) -> KeyVoxURLRoute? {
        KeyVoxURLRoute(url: url)
    }

    func handle(route: KeyVoxURLRoute, shouldPresentReturnToHost: Bool = true) {
        switch route {
        case .startRecording:
            audioModeCoordinator.handleStartRecordingCommand(isFromURL: shouldPresentReturnToHost)
        case .stopRecording:
            transcriptionManager.handleStopRecordingCommand()
        case .startTTS:
            ttsManager.isPlaybackPreparationViewPresented = shouldPresentReturnToHost
            audioModeCoordinator.handleStartTTSFromPendingRequest()
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
