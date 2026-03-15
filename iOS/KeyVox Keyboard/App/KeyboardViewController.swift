import UIKit

final class KeyboardViewController: UIInputViewController {
    private let ipcManager = KeyboardIPCManager()
    private let capsLockStateStore = KeyboardCapsLockStateStore()
    private let keypressHaptics = KeyboardKeypressHaptics()
    private let indicatorDriver = AudioIndicatorDriver()
    private let startRecordingURL = URL(string: "keyvoxios://record/start")
    private lazy var containingAppLauncher = KeyboardContainingAppLauncher(responderProvider: { [weak self] in
        self
    })
    private lazy var textInputController = KeyboardTextInputController(
        documentProxy: KeyboardTextDocumentProxyAdapter(proxyProvider: { [weak self] in
            self?.textDocumentProxy
        }),
        emitKeypress: { [weak self] in
            self?.keypressHaptics.emitKeypressIfEnabled()
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
        configureDictationBehavior()
        rootContainerView?.keyGridView.resetInteractionState()
        indicatorDriver.start()
        configurePrimaryViewHeight()
        syncCapsLockState()
        dictationController.syncStateFromSharedState()
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
        }
    }

    private func updateUI() {
        rootContainerView?.apply(
            state: keyboardState,
            symbolPage: symbolPage,
            isCapsLockEnabled: isCapsLockEnabled,
            showsLogoBar: KeyboardModelAvailability.isInstalled(),
            isTrackpadModeActive: isTrackpadModeActive
        )
        indicatorDriver.phase = keyboardState.indicatorPhase
    }

    @objc
    private func handleCancelTap() {
        dictationController.handleCancelTap()
    }

    @objc
    private func handleCapsLockTap() {
        isCapsLockEnabled = capsLockStateStore.toggle()
    }

    @objc
    private func handleMicTap() {
        dictationController.handleMicTap()
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
