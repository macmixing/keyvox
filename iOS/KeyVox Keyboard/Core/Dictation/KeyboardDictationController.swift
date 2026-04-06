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

    private var waitingForAppTimeoutAction: KeyboardScheduledAction?
    private var gracePeriodAction: KeyboardScheduledAction?

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
        warmSessionGracePeriodWithBluetoothAudio: TimeInterval = 1.5
    ) {
        self.ipcManager = ipcManager
        self.scheduleAction = scheduleAction
        self.openContainingApp = openContainingApp
        self.startRecordingURL = startRecordingURL
        self.waitingTimeoutDuration = waitingTimeoutDuration
        self.warmSessionGracePeriod = warmSessionGracePeriod
        self.warmSessionGracePeriodAfterTTSPlayback = warmSessionGracePeriodAfterTTSPlayback
        self.warmSessionGracePeriodWithBluetoothAudio = warmSessionGracePeriodWithBluetoothAudio
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
                scheduleWarmSessionGracePeriod(after: effectiveWarmSessionGracePeriod())
            } else {
                openContainingApp(startRecordingURL)
            }
        case .recording:
            state = .transcribing
            ipcManager.sendStopCommand()
        case .speaking, .pausedSpeaking:
            state = .waitingForApp
            scheduleWaitingTimeout()

            if ipcManager.isSessionWarm() {
                ipcManager.sendStartCommand()
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
    }

    private func handleTranscriptionReady(_ text: String) {
        cancelWaitingTimeout()
        onTranscriptionReady?(text)
        state = .idle
    }

    private func handleNoSpeech() {
        cancelWaitingTimeout()
        cancelGracePeriod()
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
            guard let self, self.state == .waitingForApp else { return }
            guard self.ipcManager.currentRecordingState() != .recording else { return }
            self.openContainingApp(self.startRecordingURL)
        }
    }

    private func cancelGracePeriod() {
        gracePeriodAction?.cancel()
        gracePeriodAction = nil
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
