import Combine
import Foundation

@MainActor
final class AudioModeCoordinator: ObservableObject {
    private let transcriptionManager: TranscriptionManager
    private let ttsManager: TTSManager
    private var isTransitioning = false

    init(
        transcriptionManager: TranscriptionManager,
        ttsManager: TTSManager
    ) {
        self.transcriptionManager = transcriptionManager
        self.ttsManager = ttsManager
    }

    func handleStartRecordingCommand(isFromURL: Bool = false) {
        Task { @MainActor in
            guard !isTransitioning else { return }
            isTransitioning = true
            defer { isTransitioning = false }

            if ttsManager.isActive {
                await ttsManager.stopPlayback()
            }

            await transcriptionManager.performStartRecordingCommand(isFromURL: isFromURL)
        }
    }

    func handleStartTTSFromPendingRequest() {
        Task { @MainActor in
            guard !isTransitioning else { return }
            isTransitioning = true
            defer { isTransitioning = false }

            if transcriptionManager.state != .idle {
                await transcriptionManager.performCancelCurrentUtterance()
            }

            await ttsManager.startPlaybackFromPendingRequest()
        }
    }

    func handleSpeakClipboardFromApp() {
        Task { @MainActor in
            guard !isTransitioning else { return }
            isTransitioning = true
            defer { isTransitioning = false }

            if ttsManager.isActive {
                await ttsManager.stopPlayback()
                return
            }

            if transcriptionManager.state != .idle {
                await transcriptionManager.performCancelCurrentUtterance()
            }

            await ttsManager.startPlaybackFromClipboard()
        }
    }

    func handleStopTTS() {
        Task { @MainActor in
            await ttsManager.stopPlayback()
        }
    }
}
