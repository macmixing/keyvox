import Foundation

protocol KeyboardTTSIPCManaging: AnyObject {
    var onTTSPreparing: (() -> Void)? { get set }
    var onTTSPlaying: (() -> Void)? { get set }
    var onTTSFinished: (() -> Void)? { get set }
    var onTTSError: ((String?) -> Void)? { get set }

    func sendStartTTSCommand()
    func sendStopTTSCommand()
    func currentKeyboardState() -> KeyboardState
    func reconcileKeyboardStateIfNeeded() -> KeyboardState
    func isSessionWarm() -> Bool
}

extension KeyboardIPCManager: KeyboardTTSIPCManaging {}

final class KeyboardTTSController {
    var onStateChange: ((KeyboardState) -> Void)?

    private let ipcManager: any KeyboardTTSIPCManaging
    private let scheduleAction: KeyboardActionScheduler
    private let openContainingApp: (URL?) -> Void
    private let startTTSURL: URL?
    private let clipboardTextProvider: () -> String?
    private let selectedVoiceIDProvider: () -> String
    private let requestWriter: (KeyVoxTTSRequest) -> Void
    private let waitingTimeoutDuration: TimeInterval

    private var waitingForAppTimeoutAction: KeyboardScheduledAction?

    private(set) var state: KeyboardState = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    init(
        ipcManager: any KeyboardTTSIPCManaging,
        scheduleAction: @escaping KeyboardActionScheduler,
        openContainingApp: @escaping (URL?) -> Void,
        startTTSURL: URL?,
        clipboardTextProvider: @escaping () -> String?,
        selectedVoiceIDProvider: @escaping () -> String,
        requestWriter: @escaping (KeyVoxTTSRequest) -> Void,
        waitingTimeoutDuration: TimeInterval = 5
    ) {
        self.ipcManager = ipcManager
        self.scheduleAction = scheduleAction
        self.openContainingApp = openContainingApp
        self.startTTSURL = startTTSURL
        self.clipboardTextProvider = clipboardTextProvider
        self.selectedVoiceIDProvider = selectedVoiceIDProvider
        self.requestWriter = requestWriter
        self.waitingTimeoutDuration = waitingTimeoutDuration
        configureIPC()
    }

    deinit {
        cancelPendingWork()
        ipcManager.onTTSPreparing = nil
        ipcManager.onTTSPlaying = nil
        ipcManager.onTTSFinished = nil
        ipcManager.onTTSError = nil
    }

    func syncStateFromSharedState() {
        cancelWaitingTimeout()
        state = ipcManager.reconcileKeyboardStateIfNeeded()
        if state == .waitingForApp {
            scheduleWaitingTimeout()
        }
    }

    func handleSpeakTap() {
        syncStateFromSharedState()

        switch state {
        case .speaking:
            cancelPendingWork()
            ipcManager.sendStopTTSCommand()
            state = .idle
        case .waitingForApp:
            break
        case .idle, .recording, .transcribing:
            guard let request = makeClipboardRequest() else { return }
            requestWriter(request)

            state = .waitingForApp
            scheduleWaitingTimeout()
            openContainingApp(startTTSURL)
        }
    }

    func cancelPendingWork() {
        waitingForAppTimeoutAction?.cancel()
        waitingForAppTimeoutAction = nil
    }

    private func configureIPC() {
        ipcManager.onTTSPreparing = { [weak self] in
            self?.handleTTSPreparing()
        }
        ipcManager.onTTSPlaying = { [weak self] in
            self?.handleTTSPlaying()
        }
        ipcManager.onTTSFinished = { [weak self] in
            self?.handleTTSFinished()
        }
        ipcManager.onTTSError = { [weak self] _ in
            self?.handleTTSError()
        }
    }

    private func makeClipboardRequest() -> KeyVoxTTSRequest? {
        guard let text = clipboardTextProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.isEmpty == false else {
            return nil
        }

        return KeyVoxTTSRequest(
            id: UUID(),
            text: text,
            createdAt: Date().timeIntervalSince1970,
            sourceSurface: .keyboard,
            voiceID: selectedVoiceIDProvider(),
            kind: .speakClipboardText
        )
    }

    private func handleTTSPreparing() {
        state = .waitingForApp
    }

    private func handleTTSPlaying() {
        cancelWaitingTimeout()
        state = .speaking
    }

    private func handleTTSFinished() {
        cancelWaitingTimeout()
        state = .idle
    }

    private func handleTTSError() {
        cancelWaitingTimeout()
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
    }
}
