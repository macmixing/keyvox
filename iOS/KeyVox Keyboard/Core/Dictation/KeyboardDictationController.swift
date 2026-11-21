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
    var onRecordingStartFailed: (() -> Void)? { get set }
    var onTranscribingStarted: (() -> Void)? { get set }
    var onTranscriptionReady: ((String) -> Void)? { get set }
    var onNoSpeech: (() -> Void)? { get set }

    func registerObservers()
    func unregisterObservers()
    func sendStartCommand()
    func sendStopCommand()
    func sendCancelCommand()
    func clearRecordingStartFailure()
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
        case .startFailed:
            return .dictationStartFailed
        case .transcribing:
            return .transcribing
        }
    }
}

final class KeyboardDictationController {
    var onStateChange: ((KeyboardState) -> Void)?
    var onTranscriptionReady: ((String) -> Void)?

    private let ipcManager: any KeyboardDictationIPCManaging
    private let standaloneDictation: (any KeyboardStandaloneDictating)?
    private let scheduleAction: KeyboardActionScheduler
    private let openContainingApp: (URL?) -> Void
    private let startRecordingURL: URL?
    private let waitingTimeoutDuration: TimeInterval
    private let failureDisplayDuration: TimeInterval
    private let warmSessionGracePeriod: TimeInterval
    private let warmSessionGracePeriodAfterTTSPlayback: TimeInterval
    private let warmSessionGracePeriodWithBluetoothAudio: TimeInterval
    private let maxTranscriptionReconciliationRetries: Int

    private var waitingForAppTimeoutAction: KeyboardScheduledAction?
    private var failureResetAction: KeyboardScheduledAction?
    private var gracePeriodAction: KeyboardScheduledAction?
    private var transcriptionReconciliationAction: KeyboardScheduledAction?
    private var transcriptionReconciliationRetryCount = 0
    /// Whether the current dictation runs in the keyboard, without the containing app.
    private var isStandaloneDictationActive = false

    private(set) var state: KeyboardState = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    init(
        ipcManager: any KeyboardDictationIPCManaging,
        standaloneDictation: (any KeyboardStandaloneDictating)? = nil,
        scheduleAction: @escaping KeyboardActionScheduler,
        openContainingApp: @escaping (URL?) -> Void,
        startRecordingURL: URL?,
        waitingTimeoutDuration: TimeInterval = 5,
        failureDisplayDuration: TimeInterval = KeyVoxIPCBridge.recordingStartFailureDisplayDuration,
        warmSessionGracePeriod: TimeInterval = 0.5,
        warmSessionGracePeriodAfterTTSPlayback: TimeInterval = 0.5,
        warmSessionGracePeriodWithBluetoothAudio: TimeInterval = 1.5,
        maxTranscriptionReconciliationRetries: Int = 10
    ) {
        self.ipcManager = ipcManager
        self.standaloneDictation = standaloneDictation
        self.scheduleAction = scheduleAction
        self.openContainingApp = openContainingApp
        self.startRecordingURL = startRecordingURL
        self.waitingTimeoutDuration = waitingTimeoutDuration
        self.failureDisplayDuration = failureDisplayDuration
        self.warmSessionGracePeriod = warmSessionGracePeriod
        self.warmSessionGracePeriodAfterTTSPlayback = warmSessionGracePeriodAfterTTSPlayback
        self.warmSessionGracePeriodWithBluetoothAudio = warmSessionGracePeriodWithBluetoothAudio
        self.maxTranscriptionReconciliationRetries = maxTranscriptionReconciliationRetries
        configureIPC()
        configureStandaloneDictation()
    }

    deinit {
        cancelPendingWork()
    }

    func registerObservers() {
        configureIPC()
        configureStandaloneDictation()
        ipcManager.registerObservers()
        if let standaloneDictation, standaloneDictation.isAvailable {
            standaloneDictation.prepare()
        }
    }

    func unregisterObservers() {
        cancelPendingWork()
        ipcManager.unregisterObservers()
        ipcManager.onRecordingStarted = nil
        ipcManager.onRecordingStartFailed = nil
        ipcManager.onTranscribingStarted = nil
        ipcManager.onTranscriptionReady = nil
        ipcManager.onNoSpeech = nil
        // The keyboard is going away: a dictation still recording or being transcribed is
        // finished in the background so the next keyboard can offer it.
        if isStandaloneDictationActive, state == .recording || state == .transcribing {
            standaloneDictation?.finishInBackground()
        }
        isStandaloneDictationActive = false
        standaloneDictation?.deactivate()
        standaloneDictation?.onRecordingStarted = nil
        standaloneDictation?.onRecordingStartFailed = nil
        standaloneDictation?.onTranscribingStarted = nil
        standaloneDictation?.onTranscriptionReady = nil
        standaloneDictation?.onNoSpeech = nil
        standaloneDictation?.onFailure = nil
    }

    /// Ends a dictation the keyboard is still recording, which it cannot keep doing once its
    /// host app is no longer in front. A recording, or one already being transcribed, is finished
    /// in the background so the next keyboard can offer its transcript instead of inserting it
    /// into a host that is not in front; one still starting is cancelled.
    func endStandaloneRecordingForHostLeaving() {
        guard isStandaloneDictationActive else { return }
        switch state {
        case .recording, .transcribing:
            cancelWaitingTimeout()
            isStandaloneDictationActive = false
            standaloneDictation?.finishInBackground()
            state = .idle
        case .startingDictation:
            handleCancelTap()
        default:
            break
        }
    }

    func syncStateFromSharedState() {
        // The shared state describes the containing app's session, not a dictation in the keyboard.
        guard !isStandaloneDictationActive else { return }
        cancelWaitingTimeout()

        let sharedState = ipcManager.reconciledRecordingStateIfNeeded()
        if sharedState == .dictationStartFailed {
            ipcManager.clearRecordingStartFailure()
            presentRecordingStartFailure()
            return
        }
        state = sharedState

        if sharedState == .waitingForApp {
            scheduleWaitingTimeout()
        }
    }

    func handleCancelTap() {
        cancelWaitingTimeout()
        cancelTranscriptionReconciliation()
        if isStandaloneDictationActive {
            isStandaloneDictationActive = false
            standaloneDictation?.cancel()
        } else {
            ipcManager.sendCancelCommand()
        }
        state = .idle
    }

    func handleMicTap() {
        syncStateFromSharedState()

        switch state {
        case .idle:
            if ipcManager.isSessionWarm() {
                state = .waitingForApp
                scheduleWaitingTimeout()
                ipcManager.sendStartCommand()
                handleRecordingStarted()
                scheduleWarmSessionGracePeriod(after: effectiveWarmSessionGracePeriod())
            } else if let standaloneDictation, standaloneDictation.isAvailable {
                isStandaloneDictationActive = true
                state = .startingDictation
                scheduleStandaloneStartTimeout()
                standaloneDictation.start()
            } else {
                state = .waitingForApp
                scheduleWaitingTimeout()
                openContainingApp(startRecordingURL)
            }
        case .recording:
            state = .transcribing
            if isStandaloneDictationActive {
                standaloneDictation?.stop()
            } else {
                ipcManager.sendStopCommand()
                scheduleTranscriptionReconciliation()
            }
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
        case .waitingForApp, .startingDictation, .dictationStartFailed, .preparingPlayback, .transcribing:
            break
        }
    }

    func cancelPendingWork() {
        waitingForAppTimeoutAction?.cancel()
        waitingForAppTimeoutAction = nil
        cancelFailureReset()
        cancelGracePeriod()
        cancelTranscriptionReconciliation()
    }

    private func configureIPC() {
        ipcManager.onRecordingStarted = { [weak self] in
            self?.handleRecordingStarted()
        }
        ipcManager.onRecordingStartFailed = { [weak self] in
            self?.handleRecordingStartFailed()
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

    private func configureStandaloneDictation() {
        standaloneDictation?.onRecordingStarted = { [weak self] in
            guard let self, self.isStandaloneDictationActive else { return }
            self.handleRecordingStarted()
        }
        standaloneDictation?.onRecordingStartFailed = { [weak self] in
            guard let self, self.isStandaloneDictationActive else { return }
            self.isStandaloneDictationActive = false
            self.presentRecordingStartFailure()
        }
        standaloneDictation?.onTranscribingStarted = { [weak self] in
            guard let self, self.isStandaloneDictationActive else { return }
            self.cancelWaitingTimeout()
            self.state = .transcribing
        }
        standaloneDictation?.onTranscriptionReady = { [weak self] text in
            guard let self, self.isStandaloneDictationActive else { return }
            self.isStandaloneDictationActive = false
            self.handleTranscriptionReady(text)
        }
        standaloneDictation?.onNoSpeech = { [weak self] in
            guard let self, self.isStandaloneDictationActive else { return }
            self.isStandaloneDictationActive = false
            self.handleNoSpeech()
        }
        standaloneDictation?.onFailure = { [weak self] in
            guard let self, self.isStandaloneDictationActive else { return }
            self.fallBackToContainingApp()
        }
    }

    /// Hands a dictation the keyboard could not run itself to the containing app.
    private func fallBackToContainingApp() {
        isStandaloneDictationActive = false
        standaloneDictation?.cancel()
        state = .waitingForApp
        scheduleWaitingTimeout()
        openContainingApp(startRecordingURL)
    }

    private func handleRecordingStarted() {
        cancelWaitingTimeout()
        cancelFailureReset()
        state = .recording
    }

    private func handleRecordingStartFailed() {
        let shouldPresentFailure = state == .waitingForApp || state == .recording
        ipcManager.clearRecordingStartFailure()
        guard shouldPresentFailure else { return }
        presentRecordingStartFailure()
    }

    private func handleTranscribingStarted() {
        cancelWaitingTimeout()
        cancelGracePeriod()
        state = .transcribing
        scheduleTranscriptionReconciliation()
    }

    private func handleTranscriptionReady(_ text: String) {
        guard state != .idle else {
            return
        }
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
            self.presentRecordingStartFailure()
        }
    }

    /// A recording that never starts, as when a call holds the microphone, has failed to start,
    /// the same as one the containing app could not start.
    private func scheduleStandaloneStartTimeout() {
        cancelWaitingTimeout()
        waitingForAppTimeoutAction = scheduleAction(waitingTimeoutDuration) { [weak self] in
            guard let self, self.isStandaloneDictationActive, self.state == .startingDictation else { return }
            self.isStandaloneDictationActive = false
            self.standaloneDictation?.cancel()
            self.presentRecordingStartFailure()
        }
    }

    private func presentRecordingStartFailure() {
        cancelWaitingTimeout()
        cancelTranscriptionReconciliation()
        cancelFailureReset()
        state = .dictationStartFailed
        failureResetAction = scheduleAction(failureDisplayDuration) { [weak self] in
            guard let self, self.state == .dictationStartFailed else { return }
            self.failureResetAction = nil
            self.ipcManager.clearRecordingStartFailure()
            self.state = .idle
        }
    }

    private func cancelFailureReset() {
        failureResetAction?.cancel()
        failureResetAction = nil
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
                if self.shouldResendStopForTranscriptionReconciliation() {
                    self.ipcManager.sendStopCommand()
                }
                self.scheduleTranscriptionReconciliation()
            case .waitingForApp, .startingDictation, .dictationStartFailed, .preparingPlayback, .speaking, .pausedSpeaking:
                self.scheduleTranscriptionReconciliation()
            }
        }
    }

    private func shouldResendStopForTranscriptionReconciliation() -> Bool {
        transcriptionReconciliationRetryCount += 1
        return transcriptionReconciliationRetryCount <= maxTranscriptionReconciliationRetries
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
