import UIKit

final class KeyboardViewController: UIInputViewController {
    private let ipcManager = KeyboardIPCManager()
    private let capsLockStateStore = KeyboardCapsLockStateStore()
    private let keypressHaptics = KeyboardKeypressHaptics()
    private let indicatorDriver = AudioIndicatorDriver()
    private let startRecordingURL = URL(string: "keyvoxios://record/start")
    private var primaryHeightConstraint: NSLayoutConstraint?
    private var keyboardState: KeyboardState = .idle {
        didSet {
            updateUI()
        }
    }
    private var symbolPage: KeyboardSymbolPage = .primary {
        didSet {
            updateUI()
        }
    }
    private var isCapsLockEnabled = false {
        didSet {
            updateUI()
        }
    }

    private var rootContainerView: KeyboardRootView!
    private let popupOverlayView = UIView()
    private var waitingForAppTimeoutWorkItem: DispatchWorkItem?
    private var gracePeriodWorkItem: DispatchWorkItem?
    private var cursorTrackpadInteractor = KeyboardCursorTrackpadInteractor()
    private var extensionHostIsActive = true
    private var hostWillResignActiveObserver: NSObjectProtocol?
    private var hostDidBecomeActiveObserver: NSObjectProtocol?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        configureDictationBehavior()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDictationBehavior()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        configureRootView()
        configureIndicatorDriver()
        configureIPC()
        configureHostLifecycleObservers()
        syncCapsLockState()
        syncKeyboardStateFromSharedState()
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureDictationBehavior()
        rootContainerView?.keyGridView.resetInteractionState()
        indicatorDriver.start()
        configurePrimaryViewHeight()
        syncCapsLockState()
        syncKeyboardStateFromSharedState()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        rootContainerView?.keyGridView.resetInteractionState()
        indicatorDriver.stop()
        if extensionHostIsActive {
            resetCapsLockStateIfNeeded()
        }
    }

    deinit {
        indicatorDriver.stop()
        waitingForAppTimeoutWorkItem?.cancel()
        gracePeriodWorkItem?.cancel()
        if let hostWillResignActiveObserver {
            NotificationCenter.default.removeObserver(hostWillResignActiveObserver)
        }
        if let hostDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(hostDidBecomeActiveObserver)
        }
        ipcManager.unregisterObservers()
    }

    private func configureDictationBehavior() {
        hasDictationKey = true
    }

    private func configureRootView() {
        if rootContainerView == nil {
            view.backgroundColor = .clear
            view.clipsToBounds = true

            let rootView = KeyboardRootView()
            rootView.translatesAutoresizingMaskIntoConstraints = false
            rootContainerView = rootView

            popupOverlayView.translatesAutoresizingMaskIntoConstraints = false
            popupOverlayView.backgroundColor = .clear
            popupOverlayView.isUserInteractionEnabled = false
            popupOverlayView.clipsToBounds = false

            view.addSubview(rootView)
            view.addSubview(popupOverlayView)

            NSLayoutConstraint.activate([
                rootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                rootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                rootView.topAnchor.constraint(equalTo: view.topAnchor),
                rootView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                popupOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                popupOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                popupOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
                popupOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        rootContainerView.cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
        rootContainerView.capsLockButton.addTarget(self, action: #selector(handleCapsLockTap), for: .touchUpInside)
        rootContainerView.logoBarView.addTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
        rootContainerView.keyGridView.onKeyActivated = { [weak self] kind in
            self?.handleKeyActivation(kind)
        }
        rootContainerView.keyGridView.onSpaceTrackpadEvent = { [weak self] event in
            self?.handleSpaceTrackpadEvent(event)
        }
        rootContainerView.keyGridView.setPopupContainerView(popupOverlayView)
    }

    private func configureIndicatorDriver() {
        indicatorDriver.sampleProvider = { [weak self] in
            self?.ipcManager.currentAudioIndicatorSample()
        }
        indicatorDriver.onUpdate = { [weak self] timelineState in
            self?.rootContainerView?.logoBarView.applyTimelineState(timelineState)
        }
    }

    private func configurePrimaryViewHeight() {
        primaryHeightConstraint?.isActive = false
        primaryHeightConstraint = nil

        for constraint in view.constraints where constraint.firstAttribute == .height {
            view.removeConstraint(constraint)
        }

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: KeyboardStyle.keyboardHeight)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
        primaryHeightConstraint = heightConstraint
    }

    private func configureIPC() {
        ipcManager.onRecordingStarted = { [weak self] in
            self?.cancelWaitingTimeout()
            self?.keyboardState = .recording
        }
        ipcManager.onTranscribingStarted = { [weak self] in
            self?.cancelWaitingTimeout()
            self?.cancelGracePeriod()
            self?.keyboardState = .transcribing
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

    private func configureHostLifecycleObservers() {
        guard hostWillResignActiveObserver == nil, hostDidBecomeActiveObserver == nil else { return }

        hostWillResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSExtensionHostWillResignActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.extensionHostIsActive = false
        }

        hostDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSExtensionHostDidBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.extensionHostIsActive = true
        }
    }

    private func syncKeyboardStateFromSharedState() {
        cancelWaitingTimeout()

        switch ipcManager.reconcileStaleSharedStateIfNeeded() {
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
        rootContainerView?.apply(
            state: keyboardState,
            symbolPage: symbolPage,
            isCapsLockEnabled: isCapsLockEnabled
        )
        indicatorDriver.phase = keyboardState.indicatorPhase
    }

    @objc
    private func handleCancelTap() {
        cancelWaitingTimeout()
        ipcManager.sendCancelCommand()
        keyboardState = .idle
    }

    @objc
    private func handleCapsLockTap() {
        isCapsLockEnabled = capsLockStateStore.toggle()
    }

    @objc
    private func handleMicTap() {
        syncKeyboardStateFromSharedState()

        switch keyboardState {
        case .idle:
            keyboardState = .waitingForApp
            scheduleWaitingTimeout()

            let isWarm = ipcManager.isSessionWarm()

            if isWarm {
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
                openContainingAppIfPossible(startRecordingURL)
            }
        case .recording:
            keyboardState = .transcribing
            ipcManager.sendStopCommand()
        case .waitingForApp, .transcribing:
            break
        }
    }

    private func handleKeyActivation(_ kind: KeyboardKeyKind) {
        keypressHaptics.emitKeypressIfEnabled()

        switch kind {
        case let .character(value):
            textDocumentProxy.insertText(value)
        case .delete:
            textDocumentProxy.deleteBackward()
        case .space:
            textDocumentProxy.insertText(" ")
        case .returnKey:
            textDocumentProxy.insertText("\n")
        case .abc:
            resetCapsLockStateIfNeeded()
            advanceToNextInputMode()
        case .alternateSymbols, .numberSymbols:
            symbolPage.toggle()
        }
    }

    private func handleSpaceTrackpadEvent(_ event: KeyboardSpaceTrackpadEvent) {
        switch event {
        case .began:
            cursorTrackpadInteractor.begin()
        case let .moved(delta):
            cursorTrackpadInteractor.handleMovement(
                delta: delta,
                adjustCursor: { [weak self] offset in
                    self?.adjustCursorPosition(by: offset)
                }
            )
        case .ended, .cancelled:
            cursorTrackpadInteractor.end()
        }
    }

    private func adjustCursorPosition(by offset: Int) {
        guard offset != 0 else { return }

        let step = offset > 0 ? 1 : -1
        for _ in 0..<abs(offset) {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: step)
        }
    }

    private func syncCapsLockState() {
        isCapsLockEnabled = capsLockStateStore.isEnabled
    }

    private func resetCapsLockStateIfNeeded() {
        guard isCapsLockEnabled else { return }
        capsLockStateStore.setEnabled(false)
        isCapsLockEnabled = false
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

        let insertionText = KeyboardInsertionSpacingHeuristics.applySmartLeadingSeparatorIfNeeded(
            to: cleanedText,
            documentContextBeforeInput: textDocumentProxy.documentContextBeforeInput
        )
        textDocumentProxy.insertText(insertionText)
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
