import UIKit

final class KeyboardViewController: UIInputViewController {
    private let ipcManager = KeyboardIPCManager()
    private let startRecordingURL = URL(string: "keyvoxios://record/start")
    private var keyboardState: KeyboardState = .idle {
        didSet {
            updateUI()
        }
    }

    private var rootContainerView: KeyboardRootView!
    private var waitingForAppTimeoutWorkItem: DispatchWorkItem?
    private var gracePeriodWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureRootView()
        configureIPC()
        syncKeyboardStateFromSharedState()
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncKeyboardStateFromSharedState()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateUI()
    }

    deinit {
        waitingForAppTimeoutWorkItem?.cancel()
        gracePeriodWorkItem?.cancel()
        ipcManager.unregisterObservers()
    }

    private func configureRootView() {
        let rootView = KeyboardRootView()
        view.backgroundColor = .clear
        view.addSubview(rootView)
        NSLayoutConstraint.activate([
            rootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootView.topAnchor.constraint(equalTo: view.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        rootView.micButton.addTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
        rootView.nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        rootContainerView = rootView
    }

    private func configureIPC() {
        ipcManager.onRecordingStarted = { [weak self] in
            self?.cancelWaitingTimeout()
            self?.keyboardState = .recording
        }
        ipcManager.onTranscriptionReady = { [weak self] text in
            self?.cancelWaitingTimeout()
            self?.insertTranscription(text)
        }
        ipcManager.onNoSpeech = { [weak self] in
            self?.cancelWaitingTimeout()
            self?.cancelGracePeriod()
            self?.keyboardState = .idle
        }
        ipcManager.registerObservers()
    }

    private func syncKeyboardStateFromSharedState() {
        cancelWaitingTimeout()

        switch ipcManager.currentSharedRecordingState() {
        case .idle:
            keyboardState = .idle
        case .waitingForApp:
            keyboardState = .waitingForApp
            scheduleWaitingTimeout()
        case .recording:
            keyboardState = .recording
        case .transcribing:
            keyboardState = .transcribing
        }
    }

    private func updateUI() {
        rootContainerView?.apply(state: keyboardState, showsNextKeyboard: needsInputModeSwitchKey)
    }

    @objc
    private func handleMicTap() {
        switch keyboardState {
        case .idle:
            keyboardState = .waitingForApp
            scheduleWaitingTimeout()
            
            let isWarm = ipcManager.isSessionWarm()
            
            if isWarm {
                // 1. If warm, send command and wait 500ms
                ipcManager.sendStartCommand()
                
                cancelGracePeriod()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self, self.keyboardState == .waitingForApp else { return }
                    if self.ipcManager.currentSharedRecordingState() != .recording {
                        self.openContainingAppIfPossible(self.startRecordingURL)
                    }
                }
                gracePeriodWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
            } else {
                // 2. If cold, launch IMMEDIATELY to preserve touch context.
                // The URL scheme handles the "Start" command on the app side.
                openContainingAppIfPossible(startRecordingURL)
            }
        case .recording:
            keyboardState = .transcribing
            ipcManager.sendStopCommand()
        case .waitingForApp, .transcribing:
            break
        }
    }

    private func scheduleWaitingTimeout() {
        cancelWaitingTimeout()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.keyboardState == .waitingForApp else { return }
            self.keyboardState = .idle
        }
        waitingForAppTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func cancelWaitingTimeout() {
        waitingForAppTimeoutWorkItem?.cancel()
        waitingForAppTimeoutWorkItem = nil
        cancelGracePeriod()
    }

    private func cancelGracePeriod() {
        gracePeriodWorkItem?.cancel()
        gracePeriodWorkItem = nil
    }

    private func insertTranscription(_ text: String) {
        let cleanedText = text.replacingOccurrences(
            of: #"[\r\n]+$"#,
            with: "",
            options: .regularExpression
        )
        guard !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            keyboardState = .idle
            return
        }

        textDocumentProxy.insertText(cleanedText)
        keyboardState = .idle
    }

    private func openContainingAppIfPossible(_ url: URL?) {
        guard let url else { return }

        let modernSelector = NSSelectorFromString("openURL:options:completionHandler:")
        let legacySelector = NSSelectorFromString("openURL:")

        var responder: UIResponder? = self
        while let currentResponder = responder {
            if currentResponder.responds(to: modernSelector) {
                _ = currentResponder.perform(modernSelector, with: url, with: nil)
                return
            }

            if currentResponder.responds(to: legacySelector) {
                _ = currentResponder.perform(legacySelector, with: url)
                return
            }

            responder = currentResponder.next
        }

#if DEBUG
        print("KeyboardViewController: unable to open containing app for URL \(url.absoluteString)")
#endif
    }
}
