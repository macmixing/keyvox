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

    private var isRegistered = false
    private var heartbeatTimer: Timer?

    func registerObservers() {
        guard !isRegistered else { return }
        isRegistered = true

        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.startRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.stopRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.cancelRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.disableSession)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.startTTS)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.stopTTS)
        
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
        KeyVoxIPCBridge.setTTSState(.preparing)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsPreparing)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTTSPlaying() {
        KeyVoxIPCBridge.setTTSState(.playing)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsPlaying)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTTSFinished() {
        KeyVoxIPCBridge.setTTSState(.finished)
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        KeyVoxIPCBridge.clearTTSPlaybackMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsFinished)
        KeyVoxIPCBridge.touchHeartbeat()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            KeyVoxIPCBridge.clearTTSState()
        }
    }

    func publishTTSFailed(message: String?) {
        KeyVoxIPCBridge.setTTSState(.error, errorMessage: message)
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        KeyVoxIPCBridge.clearTTSPlaybackMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsFailed)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTTSStopped() {
        KeyVoxIPCBridge.clearTTSState()
        KeyVoxIPCBridge.writeLiveMeter(level: 0, signalState: .dead)
        KeyVoxIPCBridge.clearTTSPlaybackMeter()
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.ttsFinished)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishPlaybackMeter(level: Float) {
        let clampedLevel = min(max(level, 0), 1)
        let signalState: KeyVoxIPCLiveMeterSignalState

        switch clampedLevel {
        case ..<0.02:
            signalState = .dead
        default:
            signalState = clampedLevel < 0.08 ? .quiet : .active
        }

        KeyVoxIPCBridge.writeLiveMeter(level: clampedLevel, signalState: signalState)
        KeyVoxIPCBridge.writeTTSPlaybackMeter(level: clampedLevel, signalState: signalState)
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
