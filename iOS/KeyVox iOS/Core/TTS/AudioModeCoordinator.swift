import Combine
import Foundation

@MainActor
final class AudioModeCoordinator: ObservableObject {
    private let transcriptionManager: TranscriptionManager
    private let ttsManager: TTSManager
    private let appTabRouter: AppTabRouter
    private let ttsPurchaseGate: any TTSPurchaseGating
    private var isTransitioning = false
    private var shouldRepairMonitoringAfterTTS = false

    init(
        transcriptionManager: TranscriptionManager,
        ttsManager: TTSManager,
        appTabRouter: AppTabRouter,
        ttsPurchaseGate: any TTSPurchaseGating
    ) {
        self.transcriptionManager = transcriptionManager
        self.ttsManager = ttsManager
        self.appTabRouter = appTabRouter
        self.ttsPurchaseGate = ttsPurchaseGate
        self.ttsManager.onWillTeardownPlayback = { [weak self] in
            await self?.repairMonitoringAfterTTSIfNeeded()
        }
    }

    func handleStartRecordingCommand(isFromURL: Bool = false) {
        Task { @MainActor in
            guard !isTransitioning else { return }
            isTransitioning = true
            defer { isTransitioning = false }

            NSLog(
                "[AudioModeCoordinator] handleStartRecordingCommand isFromURL=%@ transcriptionState=%@ isSessionActive=%@ ttsActive=%@",
                String(isFromURL),
                String(describing: transcriptionManager.state),
                String(transcriptionManager.isSessionActive),
                String(ttsManager.isActive)
            )
            KeyVoxIPCBridge.clearRecentTTSPlayback()

            if ttsManager.isActive {
                await ttsManager.stopPlayback()
            }

            await transcriptionManager.performStartRecordingCommand(isFromURL: isFromURL)
        }
    }

    func handleStartTTSFromPendingRequest(showPreparationView: Bool = true) {
        Task { @MainActor in
            guard !isTransitioning else { return }
            isTransitioning = true
            defer { isTransitioning = false }

            NSLog(
                "[AudioModeCoordinator] handleStartTTSFromPendingRequest transcriptionState=%@ isSessionActive=%@",
                String(describing: transcriptionManager.state),
                String(transcriptionManager.isSessionActive)
            )
            guard ttsPurchaseGate.canStartNewTTSSpeak else {
                ttsManager.isPlaybackPreparationViewPresented = false
                ttsPurchaseGate.presentUnlockSheet()
                return
            }
            appTabRouter.selectedTab = .home
            shouldRepairMonitoringAfterTTS = transcriptionManager.isSessionActive
            ttsManager.setPlaybackAudioSessionMode(
                transcriptionManager.isSessionActive
                ? .playbackWhilePreservingRecording
                : .playback
            )

            if transcriptionManager.state != .idle {
                await transcriptionManager.performCancelCurrentUtterance()
            }

            await ttsManager.startPlaybackFromPendingRequest(showPreparationView: showPreparationView)
        }
    }

    func handleSpeakClipboardFromApp() {
        Task { @MainActor in
            guard !isTransitioning else { return }
            isTransitioning = true
            defer { isTransitioning = false }

            NSLog(
                "[AudioModeCoordinator] handleSpeakClipboardFromApp transcriptionState=%@ isSessionActive=%@ ttsActive=%@",
                String(describing: transcriptionManager.state),
                String(transcriptionManager.isSessionActive),
                String(ttsManager.isActive)
            )
            appTabRouter.selectedTab = .home

            if ttsManager.isActive {
                await ttsManager.stopPlayback()
                return
            }

            guard ttsPurchaseGate.canStartNewTTSSpeak else {
                ttsPurchaseGate.presentUnlockSheet()
                return
            }

            shouldRepairMonitoringAfterTTS = transcriptionManager.isSessionActive
            ttsManager.setPlaybackAudioSessionMode(
                transcriptionManager.isSessionActive
                ? .playbackWhilePreservingRecording
                : .playback
            )

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

    func handlePauseTTS() {
        ttsManager.pausePlayback()
    }

    func handleResumeTTS() {
        ttsManager.resumePlayback()
    }

    func handleReplayLastTTS() {
        Task { @MainActor in
            guard !isTransitioning else { return }
            isTransitioning = true
            defer { isTransitioning = false }

            NSLog(
                "[AudioModeCoordinator] handleReplayLastTTS transcriptionState=%@ isSessionActive=%@",
                String(describing: transcriptionManager.state),
                String(transcriptionManager.isSessionActive)
            )
            shouldRepairMonitoringAfterTTS = transcriptionManager.isSessionActive
            ttsManager.setPlaybackAudioSessionMode(
                transcriptionManager.isSessionActive
                ? .playbackWhilePreservingRecording
                : .playback
            )

            if transcriptionManager.state != .idle {
                await transcriptionManager.performCancelCurrentUtterance()
            }

            ttsManager.replayLastPlayback()
        }
    }

    private func repairMonitoringAfterTTSIfNeeded() async {
        guard shouldRepairMonitoringAfterTTS else { return }
        shouldRepairMonitoringAfterTTS = false
        await transcriptionManager.repairMonitoringSessionIfNeeded()
    }
}
