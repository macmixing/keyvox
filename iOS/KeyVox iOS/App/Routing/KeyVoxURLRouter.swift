import Foundation

@MainActor
final class KeyVoxURLRouter {
    private let audioModeCoordinator: AudioModeCoordinator
    private let transcriptionManager: TranscriptionManager
    private let ttsManager: TTSManager
    private let appTabRouter: AppTabRouter
    private let vibesPurchaseController: KeyVoxVibesPurchaseController

    init(
        transcriptionManager: TranscriptionManager,
        ttsManager: TTSManager,
        audioModeCoordinator: AudioModeCoordinator,
        appTabRouter: AppTabRouter,
        vibesPurchaseController: KeyVoxVibesPurchaseController
    ) {
        self.audioModeCoordinator = audioModeCoordinator
        self.transcriptionManager = transcriptionManager
        self.ttsManager = ttsManager
        self.appTabRouter = appTabRouter
        self.vibesPurchaseController = vibesPurchaseController
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
            if let request = KeyVoxIPCBridge.readTTSRequest(),
               request.trimmedText.isEmpty == false {
                audioModeCoordinator.handleStartTTSFromPendingRequest(
                    showPreparationView: request.sourceSurface == .keyboard && shouldPresentReturnToHost
                )
            } else {
                ttsManager.dismissPlaybackPreparationView()
                audioModeCoordinator.handleSpeakClipboardFromApp()
            }
        case .openDictionary:
            appTabRouter.selectTab(.dictionary, suppressesHaptic: true)
        case .openSettings:
            appTabRouter.selectTab(.settings, suppressesHaptic: true)
        case .openVibes:
            appTabRouter.selectTab(.style, suppressesHaptic: true)
            vibesPurchaseController.presentIntroSheet()
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
