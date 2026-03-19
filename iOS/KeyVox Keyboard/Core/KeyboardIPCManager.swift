import Foundation
import CoreFoundation

final class KeyboardIPCManager {
    enum SharedRecordingState: String {
        case idle
        case waitingForApp
        case recording
        case transcribing
    }

    var onRecordingStarted: (() -> Void)?
    var onTranscribingStarted: (() -> Void)?
    var onTranscriptionReady: ((String) -> Void)?
    var onNoSpeech: (() -> Void)?


    private var isRegistered = false

    func registerObservers() {
        guard !isRegistered else { return }
        isRegistered = true

        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.recordingStarted)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.transcribingStarted)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.transcriptionReady)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.noSpeech)
    }

    func unregisterObservers() {
        guard isRegistered else { return }
        isRegistered = false

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }

    func sendStartCommand() {
        setRecordingState("waitingForApp")
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.startRecording)
    }

    func sendStopCommand() {
        setRecordingState("transcribing")
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.stopRecording)
    }

    func sendCancelCommand() {
        KeyVoxIPCBridge.clearTransientOperationState()
        KeyVoxIPCBridge.setRecordingState("idle")
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.cancelRecording)
    }

    func currentAudioIndicatorSample() -> AudioIndicatorSample? {
        guard let snapshot = KeyVoxIPCBridge.currentLiveMeterSnapshot() else { return nil }

        return AudioIndicatorSample(
            level: snapshot.level,
            signalState: mapSignalState(snapshot.signalState),
            timestamp: snapshot.timestamp
        )
    }

    func currentSharedRecordingState() -> SharedRecordingState {
        guard let rawValue = KeyVoxIPCBridge.currentRecordingState(),
              let state = SharedRecordingState(rawValue: rawValue) else {
            return .idle
        }
        return state
    }

    func reconcileStaleSharedStateIfNeeded() -> SharedRecordingState {
        let state = currentSharedRecordingState()

        switch state {
        case .idle:
            return .idle
        case .waitingForApp:
            if let age = KeyVoxIPCBridge.currentRecordingStateAge(), age > 5 {
                KeyVoxIPCBridge.clearTransientOperationState()
                return .idle
            }
            return .waitingForApp
        case .recording, .transcribing:
            guard !isSessionWarm() else { return state }
            KeyVoxIPCBridge.clearTransientOperationState()
            return .idle
        }
    }

    func isSessionWarm() -> Bool {
        return KeyVoxIPCBridge.isSessionWarm()
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

    private func postDarwinNotification(named name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(name as CFString), nil, nil, true)
    }

    private func setRecordingState(_ value: String) {
        KeyVoxIPCBridge.setRecordingState(value)
    }

    private func latestTranscription() -> String? {
        KeyVoxIPCBridge.latestTranscription()
    }

    private func mapSignalState(_ signalState: KeyVoxIPCLiveMeterSignalState) -> AudioIndicatorSignalState {
        switch signalState {
        case .dead:
            return .inactive
        case .quiet:
            return .lowActivity
        case .active:
            return .active
        }
    }

    private func handleNotification(named name: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch name {
            case KeyVoxIPCBridge.Notification.recordingStarted:
                self.onRecordingStarted?()
            case KeyVoxIPCBridge.Notification.transcribingStarted:
                self.onTranscribingStarted?()
            case KeyVoxIPCBridge.Notification.transcriptionReady:
                guard let text = self.latestTranscription(), !text.isEmpty else {
                    self.onNoSpeech?()
                    return
                }
                self.onTranscriptionReady?(text)
            case KeyVoxIPCBridge.Notification.noSpeech:
                self.onNoSpeech?()
            default:
                break
            }
        }
    }

    nonisolated private static let notificationCallback: CFNotificationCallback = { _, observer, name, _, _ in
        guard let observer, let rawName = name?.rawValue as String? else { return }
        let manager = Unmanaged<KeyboardIPCManager>.fromOpaque(observer).takeUnretainedValue()
        manager.handleNotification(named: rawName)
    }
}
