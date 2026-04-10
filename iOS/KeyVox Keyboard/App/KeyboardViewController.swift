import AVFoundation
import UIKit

final class KeyboardViewController: UIInputViewController {
    let ipcManager = KeyboardIPCManager()
    let capsLockStateStore = KeyboardCapsLockStateStore()
    let keypressHaptics = KeyboardKeypressHaptics()
    let interactionHaptics = KeyboardInteractionHaptics()
    let indicatorDriver = AudioIndicatorDriver()
    let startRecordingURL = URL(string: "keyvoxios://record/start")
    let startTTSURL = URL(string: "keyvoxios://tts/start")
    let dictionaryCasingStore = KeyboardDictionaryCasingStore()
    let callObserver =  KeyboardCallObserver()
    lazy var containingAppLauncher = KeyboardContainingAppLauncher(responderProvider: { [weak self] in
        self
    })
    lazy var textInputController = KeyboardTextInputController(
        documentProxy: KeyboardTextDocumentProxyAdapter(proxyProvider: { [weak self] in
            self?.textDocumentProxy
        }),
        emitKeypress: { [weak self] in
            self?.keypressHaptics.emitKeypressIfEnabled()
        },
        shouldPreserveLeadingCapitalization: { [weak self] text in
            self?.dictionaryCasingStore.shouldPreserveLeadingCapitalization(in: text) ?? false
        }
    )
    lazy var dictationController = KeyboardDictationController(
        ipcManager: ipcManager,
        scheduleAction: keyboardMainQueueScheduler,
        openContainingApp: { [weak self] url in
            self?.containingAppLauncher.open(url)
        },
        startRecordingURL: startRecordingURL
    )
    lazy var ttsController = KeyboardTTSController(
        ipcManager: ipcManager,
        scheduleAction: keyboardMainQueueScheduler,
        openContainingApp: { [weak self] url in
            self?.containingAppLauncher.open(url)
        },
        startTTSURL: startTTSURL,
        clipboardTextProvider: {
            UIPasteboard.general.string
        },
        selectedVoiceIDProvider: { [fileManager = FileManager.default] in
            let defaults = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)
            let preferredVoiceID = defaults?.string(forKey: UserDefaultsKeys.ttsVoice)
            return KeyboardModelAvailability.resolvedTTSVoiceID(
                preferredVoiceID: preferredVoiceID,
                fileManager: fileManager
            ) ?? "alba"
        },
        requestWriter: { request in
            KeyVoxIPCBridge.writeTTSRequest(request)
        }
    )
    var primaryHeightConstraint: NSLayoutConstraint?
    var keyboardState: KeyboardState = .idle {
        didSet {
            updateUI()
        }
    }
    var symbolPage: KeyboardSymbolPage = .primary {
        didSet {
            updateUI()
        }
    }
    var isCapsLockEnabled = false {
        didSet {
            updateUI()
        }
    }

    var rootContainerView: KeyboardRootView?
    var popupOverlayView: UIView?
    var fullAccessView: FullAccessView?
    var cursorTrackpadInteractor = KeyboardCursorTrackpadInteractor()
    var isTrackpadModeActive = false
    var extensionHostIsActive = true
    var hostWillResignActiveObserver: NSObjectProtocol?
    var hostDidBecomeActiveObserver: NSObjectProtocol?
    var hasConfiguredControllerBindings = false
    var isPresentationBound = false

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
        configureTraitChangeObservation()
        configureHostLifecycleObservers()
        configureControllerBindingsIfNeeded()
        KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: hasFullAccess)
        syncCapsLockState()
        dictationController.syncStateFromSharedState()
        ttsController.syncStateFromSharedState()
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        extensionHostIsActive = true
        preparePresentationIfNeeded()
        KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: hasFullAccess)
        configureDictationBehavior()
        callObserver.refreshState()
        rootContainerView?.keyGridView.resetInteractionState()
        indicatorDriver.start()
        configurePrimaryViewHeight()
        syncCapsLockState()
        dictationController.syncStateFromSharedState()
        ttsController.syncStateFromSharedState()
        updateUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        KeyVoxIPCBridge.reportKeyboardOnboardingPresentation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard extensionHostIsActive else { return }
        tearDownPresentation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        rootContainerView?.keyGridView.resetInteractionState()
        if extensionHostIsActive {
            resetCapsLockStateIfNeeded()
            tearDownPresentation()
        }
    }

    deinit {
        tearDownPresentation()
        removeHostLifecycleObservers()
    }

    private func configureDictationBehavior() {
        hasDictationKey = true
    }

    func configurePrimaryViewHeight() {
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

    private func configureTraitChangeObservation() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.updateUI()
        }
    }

    private func configureControllerBindingsIfNeeded() {
        guard hasConfiguredControllerBindings == false else { return }
        hasConfiguredControllerBindings = true

        dictationController.onStateChange = { [weak self] state in
            self?.keyboardState = state
        }
        ttsController.onStateChange = { [weak self] state in
            self?.keyboardState = state
        }
        dictationController.onTranscriptionReady = { [weak self] text in
            self?.handleTranscriptionReady(text)
        }
        callObserver.onCallStateChange = { [weak self] in
            self?.updateUI()
        }
    }

    func updateUI() {
        let toolbarMode = currentToolbarMode()
        let preferredTTSVoiceID = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)?
            .string(forKey: UserDefaultsKeys.ttsVoice)
        let isTTSReady = KeyboardModelAvailability.isTTSReady(preferredVoiceID: preferredTTSVoiceID)
        rootContainerView?.apply(
            state: keyboardState,
            symbolPage: symbolPage,
            isCapsLockEnabled: isCapsLockEnabled,
            toolbarMode: toolbarMode,
            isTTSReady: isTTSReady,
            isTrackpadModeActive: isTrackpadModeActive
        )
        if toolbarMode != .fullAccessWarning {
            setFullAccessInstructionsPresented(false)
        }
        indicatorDriver.phase = keyboardState.indicatorPhase
    }

    private func currentToolbarMode() -> KeyboardToolbarMode {
        KeyboardToolbarMode.resolve(
            isModelInstalled: KeyboardModelAvailability.isInstalled(),
            hasFullAccess: hasFullAccess,
            hasMicrophonePermission: hasMicrophonePermission,
            hasActivePhoneCall: callObserver.hasActivePhoneCall,
            isUpdateRequired: KeyVoxIPCBridge.isAppUpdateRequired()
        )
    }

    func ensureFullAccessView() -> FullAccessView {
        if let fullAccessView {
            return fullAccessView
        }

        let fullAccessView = FullAccessView()
        fullAccessView.translatesAutoresizingMaskIntoConstraints = false
        fullAccessView.isHidden = true
        fullAccessView.onBack = { [weak self] in
            self?.setFullAccessInstructionsPresented(false)
        }

        view.addSubview(fullAccessView)
        NSLayoutConstraint.activate([
            fullAccessView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fullAccessView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fullAccessView.topAnchor.constraint(equalTo: view.topAnchor),
            fullAccessView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        self.fullAccessView = fullAccessView
        return fullAccessView
    }

    private var hasMicrophonePermission: Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .undetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    func setFullAccessInstructionsPresented(_ isPresented: Bool) {
        if isPresented {
            ensureFullAccessView().isHidden = false
        } else {
            fullAccessView?.isHidden = true
        }
        rootContainerView?.isHidden = isPresented
        popupOverlayView?.isHidden = isPresented
    }

    @objc
    func handleCancelTap() {
        interactionHaptics.emitWarningIfEnabled()
        if keyboardState.isTTSPlaybackActive {
            ttsController.handleStopPlaybackTap()
            return
        }

        dictationController.handleCancelTap()
    }

    @objc
    func handleCapsLockTap() {
        isCapsLockEnabled = capsLockStateStore.toggle()
        interactionHaptics.emitLightIfEnabled()
    }

    @objc
    func handleMicTap() {
        interactionHaptics.emitMediumIfEnabled()
        switch keyboardState {
        case .speaking, .pausedSpeaking:
            ttsController.handlePlaybackControlTap()
        case .idle, .waitingForApp, .preparingPlayback, .recording, .transcribing:
            dictationController.handleMicTap()
        }
    }

    @objc
    func handleSpeakTap() {
        interactionHaptics.emitMediumIfEnabled()
        ttsController.handleSpeakTap()
    }

    @objc
    func handleFullAccessInfoTap() {
        setFullAccessInstructionsPresented(true)
    }

    @discardableResult
    func handleKeyActivation(_ kind: KeyboardKeyKind) -> Bool {
        textInputController.handleKeyActivation(
            kind,
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: { [weak self] in
                self?.resetCapsLockStateIfNeeded()
            },
            advanceToNextInputMode: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )
    }

    func handleSpaceTrackpadEvent(_ event: KeyboardSpaceTrackpadEvent) {
        switch event {
        case .began:
            isTrackpadModeActive = true
            cursorTrackpadInteractor.begin()
            updateUI()
        case let .moved(delta):
            cursorTrackpadInteractor.handleMovement(
                delta: delta,
                adjustCursor: { [weak self] offset in
                    self?.textInputController.adjustCursorPosition(by: offset)
                }
            )
        case .ended, .cancelled:
            isTrackpadModeActive = false
            cursorTrackpadInteractor.end()
            updateUI()
        }
    }

    func syncCapsLockState() {
        isCapsLockEnabled = capsLockStateStore.isEnabled
    }

    private func resetCapsLockStateIfNeeded() {
        guard isCapsLockEnabled else { return }
        capsLockStateStore.setEnabled(false)
        isCapsLockEnabled = false
    }

    private func handleTranscriptionReady(_ text: String) {
        _ = textInputController.insertTranscription(text)
    }
}
