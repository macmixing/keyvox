import Foundation
import CoreFoundation

final class KeyVoxKeyboardBridge {
    private let appGroupID = SharedPaths.appGroupID
 
    var onStartRecordingCommand: (() -> Void)?
    var onStopRecordingCommand: (() -> Void)?
    var onCancelRecordingCommand: (() -> Void)?
    var onDisableSessionCommand: (() -> Void)?
    var onStartTTSCommand: (() -> Void)?
    var onStopTTSCommand: (() -> Void)?
    var onPauseTTSCommand: (() -> Void)?
    var onResumeTTSCommand: (() -> Void)?

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
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.startTTS)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.stopTTS)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.pauseTTS)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.resumeTTS)
        
        touchHeartbeat()
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
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTranscribing() {
        KeyVoxIPCBridge.setRecordingState("transcribing")
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.transcribingStarted)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTranscriptionReady(_ text: String) {
        KeyVoxIPCBridge.setTranscription(text)
        KeyVoxIPCBridge.setRecordingState("idle")
        KeyVoxIPCBridge.clearLiveMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.transcriptionReady)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishNoSpeech() {
        KeyVoxIPCBridge.clearTransientOperationState()
        KeyVoxIPCBridge.setRecordingState("idle")
        KeyVoxIPCBridge.clearLiveMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.noSpeech)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishCancelled() {
        KeyVoxIPCBridge.clearTransientOperationState()
        KeyVoxIPCBridge.setRecordingState("idle")
        KeyVoxIPCBridge.clearLiveMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.noSpeech)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTTSPreparing() {
        pendingClearWorkItem?.cancel()
        pendingClearWorkItem = nil
        KeyVoxIPCBridge.setTTSState(.preparing)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        KeyVoxIPCBridge.setTTSPlaybackProgress(0)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsPreparing)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTTSPlaying() {
        pendingClearWorkItem?.cancel()
        pendingClearWorkItem = nil
        KeyVoxIPCBridge.setTTSState(.playing)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsPlaying)
        KeyVoxIPCBridge.touchHeartbeat()
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
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTTSResumed() {
        pendingClearWorkItem?.cancel()
        pendingClearWorkItem = nil
        KeyVoxIPCBridge.setTTSState(.playing)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsResumed)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTTSFinished() {
        KeyVoxIPCBridge.setTTSState(.finished)
        KeyVoxIPCBridge.setTTSIsPaused(false)
        KeyVoxIPCBridge.setTTSPlaybackProgress(1)
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsFinished)
        KeyVoxIPCBridge.touchHeartbeat()

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
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTTSStopped() {
        KeyVoxIPCBridge.clearTTSState()
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsStopped)
        KeyVoxIPCBridge.touchHeartbeat()
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
            self?.touchHeartbeat()
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
