import Foundation
import CoreFoundation

final class KeyVoxKeyboardBridge {
    private let appGroupID = iOSSharedPaths.appGroupID
 
    var onStartRecordingCommand: (() -> Void)?
    var onStopRecordingCommand: (() -> Void)?

    private var isRegistered = false
    private var heartbeatTimer: Timer?

    func registerObservers() {
        guard !isRegistered else { return }
        isRegistered = true

        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.startRecording)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.stopRecording)
        
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
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.recordingStarted)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTranscribing() {
        KeyVoxIPCBridge.setRecordingState("transcribing")
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishTranscriptionReady(_ text: String) {
        KeyVoxIPCBridge.setTranscription(text)
        KeyVoxIPCBridge.setRecordingState("idle")
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.transcriptionReady)
        KeyVoxIPCBridge.touchHeartbeat()
    }

    func publishNoSpeech() {
        KeyVoxIPCBridge.removeTranscription()
        KeyVoxIPCBridge.setRecordingState("idle")
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.noSpeech)
        KeyVoxIPCBridge.touchHeartbeat()
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
