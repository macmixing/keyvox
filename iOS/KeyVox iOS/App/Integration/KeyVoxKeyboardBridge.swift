import Foundation
import CoreFoundation

final class KeyVoxKeyboardBridge {
    private let appGroupID = SharedPaths.appGroupID
 
    var onStartRecordingCommand: (() -> Void)?
    var onStopRecordingCommand: (() -> Void)?
    var onCancelRecordingCommand: (() -> Void)?
    var onDisableSessionCommand: (() -> Void)?
    var onStyleRewriteRequestCommand: (() -> Void)?
    var onStartTTSCommand: (() -> Void)?
    var onStopTTSCommand: (() -> Void)?
    var onPauseTTSCommand: (() -> Void)?
    var onResumeTTSCommand: (() -> Void)?
    var isWarmStartAvailable: () -> Bool = { true }

    private var isRegistered = false
    private var heartbeatTimer: Timer?
    private var pendingClearWorkItem: DispatchWorkItem?

    func registerObservers() {
        guard !isRegistered else { return }
        isRegistered = true

        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.startRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.stopRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.cancelRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.disableSession)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.styleRewriteRequested)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.startTTS)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.stopTTS)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.pauseTTS)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.resumeTTS)
        
        publishHeartbeatIfWarmStartAvailable()
        startHeartbeatTimer()
    }

    func unregisterObservers() {
        guard isRegistered else { return }
        isRegistered = false

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    func publishRecordingStarted() {
        KeyVoxIPCBridge.setRecordingState("recording")
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.recordingStarted)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishRecordingStartFailed() {
        KeyVoxIPCBridge.setRecordingState("startFailed")
        KeyVoxIPCBridge.clearLiveMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.recordingStartFailed)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishTranscribing() {
        KeyVoxIPCBridge.setRecordingState("transcribing")
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.transcribingStarted)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishTranscriptionReady(
        _ text: String,
        id: UUID,
        styleIdentifier: String?
    ) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1" {
            print("[KVXKeyboardBridge] transcriptionPayload text=\(text)")
        }
        #endif
        KeyVoxIPCBridge.setTranscription(
            text,
            id: id,
            styleIdentifier: styleIdentifier
        )
        KeyVoxIPCBridge.setRecordingState("idle")
        KeyVoxIPCBridge.clearLiveMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.transcriptionReady)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishNoSpeech() {
        KeyVoxIPCBridge.clearTransientOperationState()
        KeyVoxIPCBridge.setRecordingState("idle")
        KeyVoxIPCBridge.clearLiveMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.noSpeech)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishCancelled() {
        KeyVoxIPCBridge.clearTransientOperationState()
        KeyVoxIPCBridge.setRecordingState("idle")
        KeyVoxIPCBridge.clearLiveMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.noSpeech)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishTTSPreparing() {
        pendingClearWorkItem?.cancel()
        pendingClearWorkItem = nil
        KeyVoxIPCBridge.setTTSState(.preparing)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        KeyVoxIPCBridge.setTTSPlaybackProgress(0)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsPreparing)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishTTSPlaying() {
        pendingClearWorkItem?.cancel()
        pendingClearWorkItem = nil
        KeyVoxIPCBridge.setTTSState(.playing)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsPlaying)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishTTSPlaybackProgress(_ progress: Double) {
        KeyVoxIPCBridge.setTTSPlaybackProgress(progress)
    }

    func publishTTSPaused() {
        pendingClearWorkItem?.cancel()
        pendingClearWorkItem = nil
        KeyVoxIPCBridge.setTTSState(.playing)
        KeyVoxIPCBridge.setTTSIsPaused(true)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsPaused)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishTTSResumed() {
        pendingClearWorkItem?.cancel()
        pendingClearWorkItem = nil
        KeyVoxIPCBridge.setTTSState(.playing)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsResumed)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishTTSFinished() {
        KeyVoxIPCBridge.setTTSState(.finished)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        KeyVoxIPCBridge.setTTSPlaybackProgress(1)
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsFinished)
        publishHeartbeatIfWarmStartAvailable()

        pendingClearWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            KeyVoxIPCBridge.clearTTSState()
            self?.pendingClearWorkItem = nil
        }
        pendingClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    func publishTTSFailed(message: String?) {
        KeyVoxIPCBridge.setTTSState(.error, errorMessage: message)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        KeyVoxIPCBridge.setTTSPlaybackProgress(0)
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsFailed)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishTTSStopped() {
        KeyVoxIPCBridge.clearTTSState()
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsStopped)
        publishHeartbeatIfWarmStartAvailable()
    }

    func publishLiveMeter(level: Float, signalState: LiveInputSignalState) {
        KeyVoxIPCBridge.writeLiveMeter(level: level, signalState: signalState.ipcSignalState)
    }

    func touchHeartbeat(sessionHasBluetoothAudioRoute: Bool? = nil) {
        if let sessionHasBluetoothAudioRoute {
            KeyVoxIPCBridge.setSessionHasBluetoothAudioRoute(sessionHasBluetoothAudioRoute)
        }
        KeyVoxIPCBridge.touchHeartbeat()
    }

    private func publishHeartbeatIfWarmStartAvailable() {
        if isWarmStartAvailable() {
            KeyVoxIPCBridge.touchHeartbeat()
        } else if KeyVoxIPCBridge.isSessionWarm() {
            KeyVoxIPCBridge.clearSessionActive()
        }
    }

    private func setRecordingState(_ value: String) {
        KeyVoxIPCBridge.setRecordingState(value)
    }

    private func registerDarwinObserver(named name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            Self.notificationCallback,
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func handleNotification(named name: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch name {
            case KeyVoxIPCBridge.Notification.startRecording:
                self.onStartRecordingCommand?()
            case KeyVoxIPCBridge.Notification.stopRecording:
                self.onStopRecordingCommand?()
            case KeyVoxIPCBridge.Notification.cancelRecording:
                self.onCancelRecordingCommand?()
            case KeyVoxIPCBridge.Notification.disableSession:
                self.onDisableSessionCommand?()
            case KeyVoxIPCBridge.Notification.styleRewriteRequested:
                self.onStyleRewriteRequestCommand?()
            case KeyVoxIPCBridge.Notification.startTTS:
                self.onStartTTSCommand?()
            case KeyVoxIPCBridge.Notification.stopTTS:
                self.onStopTTSCommand?()
            case KeyVoxIPCBridge.Notification.pauseTTS:
                self.onPauseTTSCommand?()
            case KeyVoxIPCBridge.Notification.resumeTTS:
                self.onResumeTTSCommand?()
            default:
                break
            }
        }
    }

    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.publishHeartbeatIfWarmStartAvailable()
        }
    }

    private func postDarwinNotification(named name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(name as CFString), nil, nil, true)
    }

    nonisolated private static let notificationCallback: CFNotificationCallback = { _, observer, name, _, _ in
        guard let observer, let rawName = name?.rawValue as String? else { return }
        let bridge = Unmanaged<KeyVoxKeyboardBridge>.fromOpaque(observer).takeUnretainedValue()
        bridge.handleNotification(named: rawName)
    }
}

private extension LiveInputSignalState {
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
