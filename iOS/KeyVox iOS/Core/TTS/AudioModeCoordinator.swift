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

            Self.log(
                "handleStartRecordingCommand isFromURL=\(String(isFromURL)) transcriptionState=\(String(describing: transcriptionManager.state)) isSessionActive=\(String(transcriptionManager.isSessionActive)) ttsActive=\(String(ttsManager.isActive))"
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

            Self.log(
                "handleStartTTSFromPendingRequest transcriptionState=\(String(describing: transcriptionManager.state)) isSessionActive=\(String(transcriptionManager.isSessionActive))"
            )
            guard ttsPurchaseGate.canStartNewTTSSpeak else {
                ttsManager.dismissPlaybackPreparationView()
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

            Self.log(
                "handleSpeakClipboardFromApp transcriptionState=\(String(describing: transcriptionManager.state)) isSessionActive=\(String(transcriptionManager.isSessionActive)) ttsActive=\(String(ttsManager.isActive))"
            )

            if ttsManager.isActive {
                await ttsManager.stopPlayback()
                return
            }

            guard ttsPurchaseGate.canStartNewTTSSpeak else {
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

            await ttsManager.startPlaybackFromClipboard()
        }
    }

    func handleRunTTSBenchmark(text: String, label: String) {
        Task { @MainActor in
            guard !isTransitioning else { return }
            isTransitioning = true
            defer { isTransitioning = false }

            Self.log(
                "handleRunTTSBenchmark label=\(label) transcriptionState=\(String(describing: transcriptionManager.state)) isSessionActive=\(String(transcriptionManager.isSessionActive))"
            )

            guard ttsPurchaseGate.canStartNewTTSSpeak else {
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

            await ttsManager.startBenchmarkPlayback(text: text, label: label)
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

            Self.log(
                "handleReplayLastTTS transcriptionState=\(String(describing: transcriptionManager.state)) isSessionActive=\(String(transcriptionManager.isSessionActive))"
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

    private static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        NSLog("[AudioModeCoordinator] %@", message())
        #endif
    }
}
