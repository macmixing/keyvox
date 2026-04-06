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
    var onTTSPreparing: (() -> Void)?
    var onTTSPlaying: (() -> Void)?
    var onTTSPaused: (() -> Void)?
    var onTTSResumed: (() -> Void)?
    var onTTSFinished: (() -> Void)?
    var onTTSError: ((String?) -> Void)?


    private var isRegistered = false

#if DEBUG
    var debugIsRegistered: Bool {
        isRegistered
    }
#endif

    func registerObservers() {
        guard !isRegistered else { return }
        isRegistered = true

        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.recordingStarted)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.transcribingStarted)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.transcriptionReady)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.noSpeech)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.ttsPreparing)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.ttsPlaying)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.ttsPaused)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.ttsResumed)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.ttsFinished)
        registerDarwinObserver(named: KeyVoxIPCBridge.Notification.ttsFailed)
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

    func sendStartTTSCommand() {
        KeyVoxIPCBridge.setTTSState(.preparing)
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.startTTS)
    }

    func sendStopTTSCommand() {
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.stopTTS)
    }

    func sendPauseTTSCommand() {
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.pauseTTS)
    }

    func sendResumeTTSCommand() {
        postDarwinNotification(named: KeyVoxIPCBridge.Notification.resumeTTS)
    }

    func currentAudioIndicatorSample() -> AudioIndicatorSample? {
        let snapshot: KeyVoxIPCLiveMeterSnapshot?
        switch currentKeyboardState() {
        case .recording, .transcribing:
            snapshot = KeyVoxIPCBridge.currentLiveMeterSnapshot()
        case .idle, .waitingForApp, .preparingPlayback, .speaking, .pausedSpeaking:
            snapshot = nil
        }

        guard let snapshot else { return nil }

        return AudioIndicatorSample(
            level: snapshot.level,
            signalState: mapSignalState(snapshot.signalState),
            timestamp: snapshot.timestamp
        )
    }

    func currentTTSPlaybackProgress() -> CGFloat {
        CGFloat(KeyVoxIPCBridge.currentTTSPlaybackProgress())
    }

    func currentSharedRecordingState() -> SharedRecordingState {
        guard let rawValue = KeyVoxIPCBridge.currentRecordingState(),
              let state = SharedRecordingState(rawValue: rawValue) else {
            return .idle
        }
        return state
    }

    func currentKeyboardState() -> KeyboardState {
        switch KeyVoxIPCBridge.currentTTSState() {
        case .preparing, .generating:
            return .preparingPlayback
        case .playing:
            return KeyVoxIPCBridge.currentTTSIsPaused() ? .pausedSpeaking : .speaking
        case .finished, .error, .idle:
            return currentSharedRecordingState().keyboardState
        }
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

    func hasBluetoothAudioRoute() -> Bool {
        KeyVoxIPCBridge.sessionHasBluetoothAudioRoute()
    }

    func hadRecentTTSPlayback() -> Bool {
        KeyVoxIPCBridge.hadRecentTTSPlayback()
    }

    func reconcileKeyboardStateIfNeeded() -> KeyboardState {
        let ttsState = KeyVoxIPCBridge.currentTTSState()
        let isPaused = KeyVoxIPCBridge.currentTTSIsPaused()
        switch ttsState {
        case .preparing, .generating, .playing:
            if !isPaused, !isSessionWarm(), let age = KeyVoxIPCBridge.currentTTSStateAge(), age > 5 {
                KeyVoxIPCBridge.clearTTSState()
            } else {
                switch ttsState {
                case .playing:
                    return isPaused ? .pausedSpeaking : .speaking
                case .preparing, .generating:
                    return .preparingPlayback
                case .finished, .error, .idle:
                    break
                }
            }
        case .finished, .error:
            if let age = KeyVoxIPCBridge.currentTTSStateAge(), age > 5 {
                KeyVoxIPCBridge.clearTTSState()
            }
        case .idle:
            break
        }

        return reconcileStaleSharedStateIfNeeded().keyboardState
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
            case KeyVoxIPCBridge.Notification.ttsPreparing:
                self.onTTSPreparing?()
            case KeyVoxIPCBridge.Notification.ttsPlaying:
                self.onTTSPlaying?()
            case KeyVoxIPCBridge.Notification.ttsPaused:
                self.onTTSPaused?()
            case KeyVoxIPCBridge.Notification.ttsResumed:
                self.onTTSResumed?()
            case KeyVoxIPCBridge.Notification.ttsFinished:
                self.onTTSFinished?()
            case KeyVoxIPCBridge.Notification.ttsFailed:
                self.onTTSError?(KeyVoxIPCBridge.currentTTSErrorMessage())
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
