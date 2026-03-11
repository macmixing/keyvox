import Foundation
import CoreFoundation

final class KeyVoxKeyboardBridge {
    private let appGroupID = iOSSharedPaths.appGroupID
 
    var onStartRecordingCommand: (() -> Void)?
    var onStopRecordingCommand: (() -> Void)?
    var onCancelRecordingCommand: (() -> Void)?

    private var isRegistered = false
    private var heartbeatTimer: Timer?

    func registerObservers() {
        guard !isRegistered else { return }
        isRegistered = true

        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.startRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.stopRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.cancelRecording)
        
        touchHeartbeat()
    }

    func unregisterObservers() {
        guard isRegistered else { return }
        isRegistered = false

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
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

    func publishLiveMeter(level: Float, signalState: LiveInputSignalState) {
        KeyVoxIPCBridge.writeLiveMeter(level: level, signalState: signalState.ipcSignalState)
    }

    func touchHeartbeat() {
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
            default:
                break
            }
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
