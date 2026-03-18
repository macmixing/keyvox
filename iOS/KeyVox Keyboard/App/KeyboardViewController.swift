import AVFoundation
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let ipcManager = KeyboardIPCManager()
    private let capsLockStateStore = KeyboardCapsLockStateStore()
    private let keypressHaptics = KeyboardKeypressHaptics()
    private let interactionHaptics = KeyboardInteractionHaptics()
    private let indicatorDriver = AudioIndicatorDriver()
    private let startRecordingURL = URL(string: "keyvoxios://record/start")
    private let dictionaryCasingStore = KeyboardDictionaryCasingStore()
    private lazy var containingAppLauncher = KeyboardContainingAppLauncher(responderProvider: { [weak self] in
        self
    })
    private lazy var textInputController = KeyboardTextInputController(
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
    private lazy var dictationController = KeyboardDictationController(
        ipcManager: ipcManager,
        scheduleAction: keyboardMainQueueScheduler,
        openContainingApp: { [weak self] url in
            self?.containingAppLauncher.open(url)
        },
        startRecordingURL: startRecordingURL
    )
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
    private var fullAccessView: FullAccessView!
    private var cursorTrackpadInteractor = KeyboardCursorTrackpadInteractor()
    private var isTrackpadModeActive = false
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
        KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: hasFullAccess)
        view.backgroundColor = .clear
        view.clipsToBounds = true
        configureRootView()
        configureTraitChangeObservation()
        configureIndicatorDriver()
        configureDictationController()
        configureHostLifecycleObservers()
        syncCapsLockState()
        dictationController.syncStateFromSharedState()
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: hasFullAccess)
        configureDictationBehavior()
        rootContainerView?.keyGridView.resetInteractionState()
        indicatorDriver.start()
        configurePrimaryViewHeight()
        syncCapsLockState()
        dictationController.syncStateFromSharedState()
        updateUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        KeyVoxIPCBridge.reportKeyboardOnboardingPresentation()
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
        if let hostWillResignActiveObserver {
            NotificationCenter.default.removeObserver(hostWillResignActiveObserver)
        }
        if let hostDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(hostDidBecomeActiveObserver)
        }
        dictationController.unregisterObservers()
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

            let fullAccessView = FullAccessView()
            fullAccessView.translatesAutoresizingMaskIntoConstraints = false
            fullAccessView.isHidden = true
            fullAccessView.onBack = { [weak self] in
                self?.setFullAccessInstructionsPresented(false)
            }
            self.fullAccessView = fullAccessView

            view.addSubview(rootView)
            view.addSubview(popupOverlayView)
            view.addSubview(fullAccessView)

            NSLayoutConstraint.activate([
                rootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                rootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                rootView.topAnchor.constraint(equalTo: view.topAnchor),
                rootView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                popupOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                popupOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                popupOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
                popupOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                fullAccessView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                fullAccessView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                fullAccessView.topAnchor.constraint(equalTo: view.topAnchor),
                fullAccessView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        rootContainerView.cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
        rootContainerView.capsLockButton.addTarget(self, action: #selector(handleCapsLockTap), for: .touchUpInside)
        rootContainerView.logoBarView.addTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
        rootContainerView.fullAccessInfoButton.addTarget(self, action: #selector(handleFullAccessInfoTap), for: .touchUpInside)
        rootContainerView.keyGridView.onKeyActivated = { [weak self] kind in
            self?.handleKeyActivation(kind) ?? false
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

    private func configureTraitChangeObservation() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.updateUI()
        }
    }

    private func configureDictationController() {
        dictationController.onStateChange = { [weak self] state in
            self?.keyboardState = state
        }
        dictationController.onTranscriptionReady = { [weak self] text in
            self?.handleTranscriptionReady(text)
        }
        dictationController.registerObservers()
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
            guard let self else { return }
            KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: self.hasFullAccess)
            KeyVoxIPCBridge.reportKeyboardOnboardingPresentation()
            self.updateUI()
        }
    }

    private func updateUI() {
        let toolbarMode = currentToolbarMode()
        rootContainerView?.apply(
            state: keyboardState,
            symbolPage: symbolPage,
            isCapsLockEnabled: isCapsLockEnabled,
            toolbarMode: toolbarMode,
            isTrackpadModeActive: isTrackpadModeActive
        )
        if toolbarMode != .fullAccessWarning {
            setFullAccessInstructionsPresented(false)
        }
        indicatorDriver.phase = keyboardState.indicatorPhase
    }

    private func currentToolbarMode() -> KeyboardToolbarMode {
        guard KeyboardModelAvailability.isInstalled() else {
            return .hidden
        }

        guard hasFullAccess else {
            return .fullAccessWarning
        }

        guard hasMicrophonePermission else {
            return .microphoneWarning
        }

        return .branded
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

    private func setFullAccessInstructionsPresented(_ isPresented: Bool) {
        fullAccessView?.isHidden = !isPresented
        rootContainerView?.isHidden = isPresented
        popupOverlayView.isHidden = isPresented
    }

    @objc
    private func handleCancelTap() {
        interactionHaptics.emitWarningIfEnabled()
        dictationController.handleCancelTap()
    }

    @objc
    private func handleCapsLockTap() {
        isCapsLockEnabled = capsLockStateStore.toggle()
        interactionHaptics.emitLightIfEnabled()
    }

    @objc
    private func handleMicTap() {
        interactionHaptics.emitMediumIfEnabled()
        dictationController.handleMicTap()
    }

    @objc
    private func handleFullAccessInfoTap() {
        setFullAccessInstructionsPresented(true)
    }

    @discardableResult
    private func handleKeyActivation(_ kind: KeyboardKeyKind) -> Bool {
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

    private func handleSpaceTrackpadEvent(_ event: KeyboardSpaceTrackpadEvent) {
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

    private func syncCapsLockState() {
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
