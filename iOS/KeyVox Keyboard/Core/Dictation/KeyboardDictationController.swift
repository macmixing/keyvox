import Foundation

struct KeyboardScheduledAction {
    let cancel: () -> Void
}

typealias KeyboardActionScheduler = (_ delay: TimeInterval, _ action: @escaping () -> Void) -> KeyboardScheduledAction

func keyboardMainQueueScheduler(
    after delay: TimeInterval,
    action: @escaping () -> Void
) -> KeyboardScheduledAction {
    let workItem = DispatchWorkItem(block: action)
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    return KeyboardScheduledAction(cancel: {
        workItem.cancel()
    })
}

protocol KeyboardDictationIPCManaging: AnyObject {
    var onRecordingStarted: (() -> Void)? { get set }
    var onTranscribingStarted: (() -> Void)? { get set }
    var onTranscriptionReady: ((String) -> Void)? { get set }
    var onNoSpeech: (() -> Void)? { get set }

    func registerObservers()
    func unregisterObservers()
    func sendStartCommand()
    func sendStopCommand()
    func sendCancelCommand()
    func currentRecordingState() -> KeyboardState
    func reconciledRecordingStateIfNeeded() -> KeyboardState
    func currentTranscription() -> String?
    func isSessionWarm() -> Bool
    func hasBluetoothAudioRoute() -> Bool
    func hadRecentTTSPlayback() -> Bool
}

extension KeyboardIPCManager: KeyboardDictationIPCManaging {
    func currentRecordingState() -> KeyboardState {
        currentKeyboardState()
    }

    func reconciledRecordingStateIfNeeded() -> KeyboardState {
        reconcileKeyboardStateIfNeeded()
    }
}

extension KeyboardIPCManager.SharedRecordingState {
    var keyboardState: KeyboardState {
        switch self {
        case .idle:
            return .idle
        case .waitingForApp:
            return .waitingForApp
        case .recording:
            return .recording
        case .transcribing:
            return .transcribing
        }
    }
}

final class KeyboardDictationController {
    var onStateChange: ((KeyboardState) -> Void)?
    var onTranscriptionReady: ((String) -> Void)?

    private let ipcManager: any KeyboardDictationIPCManaging
    private let scheduleAction: KeyboardActionScheduler
    private let openContainingApp: (URL?) -> Void
    private let startRecordingURL: URL?
    private let waitingTimeoutDuration: TimeInterval
    private let warmSessionGracePeriod: TimeInterval
    private let warmSessionGracePeriodAfterTTSPlayback: TimeInterval
    private let warmSessionGracePeriodWithBluetoothAudio: TimeInterval
    private let maxTranscriptionReconciliationRetries: Int

    private var waitingForAppTimeoutAction: KeyboardScheduledAction?
    private var gracePeriodAction: KeyboardScheduledAction?
    private var transcriptionReconciliationAction: KeyboardScheduledAction?
    private var transcriptionReconciliationRetryCount = 0

    private(set) var state: KeyboardState = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    init(
        ipcManager: any KeyboardDictationIPCManaging,
        scheduleAction: @escaping KeyboardActionScheduler,
        openContainingApp: @escaping (URL?) -> Void,
        startRecordingURL: URL?,
        waitingTimeoutDuration: TimeInterval = 5,
        warmSessionGracePeriod: TimeInterval = 0.5,
        warmSessionGracePeriodAfterTTSPlayback: TimeInterval = 0.5,
        warmSessionGracePeriodWithBluetoothAudio: TimeInterval = 1.5,
        maxTranscriptionReconciliationRetries: Int = 10
    ) {
        self.ipcManager = ipcManager
        self.scheduleAction = scheduleAction
        self.openContainingApp = openContainingApp
        self.startRecordingURL = startRecordingURL
        self.waitingTimeoutDuration = waitingTimeoutDuration
        self.warmSessionGracePeriod = warmSessionGracePeriod
        self.warmSessionGracePeriodAfterTTSPlayback = warmSessionGracePeriodAfterTTSPlayback
        self.warmSessionGracePeriodWithBluetoothAudio = warmSessionGracePeriodWithBluetoothAudio
        self.maxTranscriptionReconciliationRetries = maxTranscriptionReconciliationRetries
        configureIPC()
    }

    deinit {
        cancelPendingWork()
    }

    func registerObservers() {
        ipcManager.registerObservers()
    }

    func unregisterObservers() {
        cancelPendingWork()
        ipcManager.unregisterObservers()
        ipcManager.onRecordingStarted = nil
        ipcManager.onTranscribingStarted = nil
        ipcManager.onTranscriptionReady = nil
        ipcManager.onNoSpeech = nil
    }

    func syncStateFromSharedState() {
        cancelWaitingTimeout()

        let sharedState = ipcManager.reconciledRecordingStateIfNeeded()
        state = sharedState

        if sharedState == .waitingForApp {
            scheduleWaitingTimeout()
        }
    }

    func handleCancelTap() {
        cancelWaitingTimeout()
        cancelTranscriptionReconciliation()
        ipcManager.sendCancelCommand()
        state = .idle
    }

    func handleMicTap() {
        syncStateFromSharedState()

        switch state {
        case .idle:
            state = .waitingForApp
            scheduleWaitingTimeout()

            if ipcManager.isSessionWarm() {
                ipcManager.sendStartCommand()
                handleRecordingStarted()
                scheduleWarmSessionGracePeriod(after: effectiveWarmSessionGracePeriod())
            } else {
                openContainingApp(startRecordingURL)
            }
        case .recording:
            state = .transcribing
            ipcManager.sendStopCommand()
            scheduleTranscriptionReconciliation()
        case .speaking, .pausedSpeaking:
            state = .waitingForApp
            scheduleWaitingTimeout()

            if ipcManager.isSessionWarm() {
                ipcManager.sendStartCommand()
                handleRecordingStarted()
                scheduleWarmSessionGracePeriod(after: effectiveWarmSessionGracePeriod())
            } else {
                openContainingApp(startRecordingURL)
            }
        case .waitingForApp, .preparingPlayback, .transcribing:
            break
        }
    }

    func cancelPendingWork() {
        waitingForAppTimeoutAction?.cancel()
        waitingForAppTimeoutAction = nil
        cancelGracePeriod()
        cancelTranscriptionReconciliation()
    }

    private func configureIPC() {
        ipcManager.onRecordingStarted = { [weak self] in
            self?.handleRecordingStarted()
        }
        ipcManager.onTranscribingStarted = { [weak self] in
            self?.handleTranscribingStarted()
        }
        ipcManager.onTranscriptionReady = { [weak self] text in
            self?.handleTranscriptionReady(text)
        }
        ipcManager.onNoSpeech = { [weak self] in
            self?.handleNoSpeech()
        }
    }

    private func handleRecordingStarted() {
        cancelWaitingTimeout()
        state = .recording
    }

    private func handleTranscribingStarted() {
        cancelWaitingTimeout()
        cancelGracePeriod()
        state = .transcribing
        scheduleTranscriptionReconciliation()
    }

    private func handleTranscriptionReady(_ text: String) {
        cancelWaitingTimeout()
        cancelTranscriptionReconciliation()
        onTranscriptionReady?(text)
        state = .idle
    }

    private func handleNoSpeech() {
        cancelWaitingTimeout()
        cancelGracePeriod()
        cancelTranscriptionReconciliation()
        state = .idle
    }

    private func scheduleWaitingTimeout() {
        cancelWaitingTimeout()
        waitingForAppTimeoutAction = scheduleAction(waitingTimeoutDuration) { [weak self] in
            guard let self, self.state == .waitingForApp else { return }
            self.state = .idle
        }
    }

    private func cancelWaitingTimeout() {
        waitingForAppTimeoutAction?.cancel()
        waitingForAppTimeoutAction = nil
        cancelGracePeriod()
    }

    private func scheduleWarmSessionGracePeriod(after delay: TimeInterval) {
        cancelGracePeriod()
        gracePeriodAction = scheduleAction(delay) { [weak self] in
            guard let self, self.state == .waitingForApp || self.state == .recording else { return }
            guard self.ipcManager.currentRecordingState() != .recording else {
                self.handleRecordingStarted()
                return
            }
            self.state = .waitingForApp
            self.openContainingApp(self.startRecordingURL)
        }
    }

    private func cancelGracePeriod() {
        gracePeriodAction?.cancel()
        gracePeriodAction = nil
    }

    private func scheduleTranscriptionReconciliation() {
        cancelTranscriptionReconciliation(resetRetryCount: false)
        transcriptionReconciliationAction = scheduleAction(warmSessionGracePeriod) { [weak self] in
            guard let self, self.state == .transcribing else { return }

            switch self.ipcManager.reconciledRecordingStateIfNeeded() {
            case .idle:
                self.transcriptionReconciliationRetryCount = 0
                guard let text = self.ipcManager.currentTranscription(),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.handleNoSpeech()
                    return
                }
                self.handleTranscriptionReady(text)
            case .recording, .transcribing:
                guard self.canRetryTranscriptionReconciliation() else { return }
                self.ipcManager.sendStopCommand()
                self.scheduleTranscriptionReconciliation()
            case .waitingForApp, .preparingPlayback, .speaking, .pausedSpeaking:
                guard self.canRetryTranscriptionReconciliation() else { return }
                self.scheduleTranscriptionReconciliation()
            }
        }
    }

    private func canRetryTranscriptionReconciliation() -> Bool {
        transcriptionReconciliationRetryCount += 1
        guard transcriptionReconciliationRetryCount <= maxTranscriptionReconciliationRetries else {
            cancelTranscriptionReconciliation()
            state = .idle
            return false
        }

        return true
    }

    private func cancelTranscriptionReconciliation(resetRetryCount: Bool = true) {
        transcriptionReconciliationAction?.cancel()
        transcriptionReconciliationAction = nil
        if resetRetryCount {
            transcriptionReconciliationRetryCount = 0
        }
    }

    private func effectiveWarmSessionGracePeriod() -> TimeInterval {
        let bluetoothGracePeriod = ipcManager.hasBluetoothAudioRoute()
            ? warmSessionGracePeriodWithBluetoothAudio
            : warmSessionGracePeriod
        let recentTTSGracePeriod = ipcManager.hadRecentTTSPlayback()
            ? warmSessionGracePeriodAfterTTSPlayback
            : warmSessionGracePeriod
        return max(bluetoothGracePeriod, recentTTSGracePeriod)
    }
}
