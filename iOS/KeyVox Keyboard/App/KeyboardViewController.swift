import AVFoundation
import KeyVoxCore
import UIKit

final class KeyboardViewController: UIInputViewController {
    let ipcManager = KeyboardIPCManager()
    let capsLockStateStore = KeyboardCapsLockStateStore()
    let keypressHaptics = KeyboardKeypressHaptics()
    let interactionHaptics = KeyboardInteractionHaptics()
    let indicatorDriver = AudioIndicatorDriver()
    let appSettingsStore = KeyboardAppSettingsStore()
    let startRecordingURL = URL(string: "keyvoxios://record/start")
    let startTTSURL = URL(string: "keyvoxios://tts/start")
    let openDictionaryURL = URL(string: "keyvoxios://tab/dictionary")
    let openSettingsURL = URL(string: "keyvoxios://tab/settings")
    let openVibesURL = URL(string: "keyvoxios://vibes/open")
    let openVibesTrialStartURL = URL(string: "keyvoxios://vibes/trial-start")
    let delayedTranscriptionLandingHapticThreshold: TimeInterval = 1
    let dictionaryCasingStore = KeyboardDictionaryCasingStore()
    let letterCaseController = KeyboardLetterCaseController()
    let predictionCoordinator = KeyboardPredictionCoordinator()
    let automaticCorrectionUndoStore = KeyboardAutomaticCorrectionUndoStore()
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
    lazy var dictationChangeController = KeyboardDictationChangeController(
        textInputController: textInputController,
        appSettingsStore: appSettingsStore
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
            updateTranscriptionLandingHapticStart(previousState: oldValue)
            updateUI()
        }
    }
    var symbolPage: KeyboardSymbolPage = .alphabetic {
        didSet {
            updateUI()
        }
    }
    var isCapsLockEnabled = false {
        didSet {
            updateUI()
        }
    }
    var predictionChoices: [KeyboardPredictionChoice] = [] {
        didSet {
            rootContainerView?.predictionBarView.apply(choices: predictionChoices)
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
    var transcriptionLandingStartedAt: Date?

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
        appSettingsStore.normalizeSelectedVibeIfNeeded()
        syncCapsLockState()
        letterCaseController.synchronize(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        )
        dictationController.syncStateFromSharedState()
        ttsController.syncStateFromSharedState()
        updateUI()
        refreshPredictionState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        extensionHostIsActive = true
        preparePresentationIfNeeded()
        KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: hasFullAccess)
        configureDictationBehavior()
        callObserver.refreshState()
        rootContainerView?.keyGridView.resetInteractionState()
        appSettingsStore.normalizeSelectedVibeIfNeeded()
        indicatorDriver.start()
        configurePrimaryViewHeight()
        syncCapsLockState()
        letterCaseController.synchronize(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        )
        dictationController.syncStateFromSharedState()
        ttsController.syncStateFromSharedState()
        updateUI()
        refreshPredictionState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        KeyVoxIPCBridge.reportKeyboardOnboardingPresentation()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateActiveInsertionVisualState()
        letterCaseController.synchronize(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        )
        synchronizeTypingKeyPresentation()
        refreshPredictionState()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        updateActiveInsertionVisualState()
        refreshPredictionState()
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
        predictionCoordinator.onChoicesChange = { [weak self] choices in
            self?.predictionChoices = choices
        }
    }

    func updateUI() {
        let diagnosticStartedAt = ProcessInfo.processInfo.systemUptime
        KeyboardTypingDiagnostics.log("ui_update_begin", fields: [
            "symbol_page": String(describing: symbolPage),
            "prediction_choice_count": predictionChoices.count,
        ])
        let toolbarMode = currentToolbarMode()
        let preferredTTSVoiceID = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)?
            .string(forKey: UserDefaultsKeys.ttsVoice)
        let isTTSReady = KeyboardModelAvailability.isTTSReady(preferredVoiceID: preferredTTSVoiceID)
        rootContainerView?.apply(
            state: keyboardState,
            symbolPage: symbolPage,
            letterCase: letterCaseController.letterCase,
            isCapsLockEnabled: isCapsLockEnabled,
            isDictationCapsApplied: dictationChangeController.displayedCapsTransformApplied,
            isDictationCapsUppercase: dictationChangeController.displayedCapsTextIsUppercase,
            displayedVibeTitle: dictationChangeController.displayedVibeTitle,
            displayedVibeStyle: dictationChangeController.displayedVibeStyle,
            isDisplayedVibeApplied: dictationChangeController.isDisplayedVibeAppliedToCurrentInsertion,
            isVibesAvailable: appSettingsStore.isVibesAvailable,
            isAutoParagraphsEnabled: dictationChangeController.displayedAutoParagraphsEnabled,
            isListFormattingEnabled: dictationChangeController.displayedListFormattingEnabled,
            isLeftHandedLayoutEnabled: appSettingsStore.isLeftHandedKeyboardLayoutEnabled,
            arePredictiveSelectionsEnabled: appSettingsStore.arePredictiveSelectionsEnabled,
            predictionChoices: predictionChoices,
            toolbarMode: toolbarMode,
            isTTSReady: isTTSReady,
            isTrackpadModeActive: isTrackpadModeActive
        )
        if toolbarMode != .fullAccessWarning {
            setFullAccessInstructionsPresented(false)
        }
        indicatorDriver.phase = keyboardState.indicatorPhase
        KeyboardTypingDiagnostics.log("ui_update_end", fields: [
            "duration_ms": ((ProcessInfo.processInfo.systemUptime - diagnosticStartedAt) * 100_000)
                .rounded() / 100,
        ])
    }

    private func currentToolbarMode() -> KeyboardToolbarMode {
        KeyboardToolbarMode.resolve(
            modelAvailability: KeyboardDictationModelStatus.availability(),
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
    func handleCapsLockLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        handleDictationChangeResult(dictationChangeController.applyCapsLongPressChange())
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
        guard keyboardState != .waitingForApp,
              keyboardState != .recording,
              keyboardState != .transcribing else { return }
        interactionHaptics.emitMediumIfEnabled()
        ttsController.handleSpeakTap()
    }

    @objc
    func handleVibesTap() {
        guard appSettingsStore.isVibesAvailable else { return }
        guard appSettingsStore.isVibesAIInstalled else {
            _ = appSettingsStore.advanceSelectedVibe()
            interactionHaptics.emitMediumIfEnabled()
            containingAppLauncher.open(openVibesTrialStartURL)
            updateUI()
            return
        }

        guard appSettingsStore.canUseVibes else {
            interactionHaptics.emitMediumIfEnabled()
            containingAppLauncher.open(openVibesURL)
            return
        }

        _ = appSettingsStore.advanceSelectedVibe()
        dictationChangeController.showSelectedVibePreference()
        interactionHaptics.emitLightIfEnabled()
        updateUI()
    }

    @objc
    func handleParagraphsTap() {
        guard dictationChangeController.hasActiveDeterministicTransform(.paragraphs) == false else {
            updateUI()
            return
        }

        _ = appSettingsStore.toggleAutoParagraphs()
        interactionHaptics.emitLightIfEnabled()
        updateUI()
    }

    @objc
    func handleListsTap() {
        guard dictationChangeController.hasActiveDeterministicTransform(.lists) == false else {
            updateUI()
            return
        }

        _ = appSettingsStore.toggleListFormatting()
        interactionHaptics.emitLightIfEnabled()
        updateUI()
    }

    @objc
    func handleDictionaryTap() {
        interactionHaptics.emitMediumIfEnabled()
        containingAppLauncher.open(openDictionaryURL)
    }

    @objc
    func handleSettingsTap() {
        interactionHaptics.emitMediumIfEnabled()
        containingAppLauncher.open(openSettingsURL)
    }

    @objc
    func handleVibesLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let didApply = await self.dictationChangeController.applyLongPressChange(
                onProcessingStart: { [weak self] in
                    self?.handleDictationChangeProcessingStart()
                },
                onProcessingEnd: { [weak self] in
                    self?.handleDictationChangeProcessingEnd()
                }
            )
            self.handleDictationChangeResult(didApply)
        }
    }

    @objc
    func handleParagraphsLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let didApply = await self.dictationChangeController.applyDeterministicLongPressChange(
                .paragraphs,
                onProcessingStart: { [weak self] in
                    self?.handleDictationChangeProcessingStart()
                },
                onProcessingEnd: { [weak self] in
                    self?.handleDictationChangeProcessingEnd()
                }
            )
            self.handleDictationChangeResult(didApply)
        }
    }

    @objc
    func handleListsLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let didApply = await self.dictationChangeController.applyDeterministicLongPressChange(
                .lists,
                onProcessingStart: { [weak self] in
                    self?.handleDictationChangeProcessingStart()
                },
                onProcessingEnd: { [weak self] in
                    self?.handleDictationChangeProcessingEnd()
                }
            )
            self.handleDictationChangeResult(didApply)
        }
    }

    @objc
    func handleFullAccessInfoTap() {
        setFullAccessInstructionsPresented(true)
    }

    @discardableResult
    func handleKeyActivation(_ activation: KeyboardKeyActivation) -> Bool {
        let kind = activation.kind
        let startedAt = ProcessInfo.processInfo.systemUptime
        KeyboardTypingDiagnostics.log("controller_activation_begin", fields: [
            "key": String(describing: kind),
            "symbol_page": String(describing: symbolPage),
        ])
        if kind == .delete, restoreAutomaticCorrectionIfAvailable() {
            KeyboardTypingDiagnostics.log("controller_activation_end", fields: [
                "key": String(describing: kind),
                "handled": true,
                "path": "correction_undo",
                "duration_ms": ((ProcessInfo.processInfo.systemUptime - startedAt) * 100_000)
                    .rounded() / 100,
            ])
            return true
        }

        if kind == .space, applyAutomaticCorrectionIfAvailable() {
            KeyboardTypingDiagnostics.log("controller_activation_end", fields: [
                "key": String(describing: kind),
                "handled": true,
                "path": "automatic_correction",
                "duration_ms": ((ProcessInfo.processInfo.systemUptime - startedAt) * 100_000)
                    .rounded() / 100,
            ])
            return true
        }

        var updatedSymbolPage = symbolPage
        let didHandle = textInputController.handleKeyActivation(
            kind,
            symbolPage: &updatedSymbolPage,
            resetCapsLockStateIfNeeded: { [weak self] in
                self?.resetCapsLockStateIfNeeded()
            },
            advanceToNextInputMode: { [weak self] in
                self?.advanceToNextInputMode()
            },
            handleShift: { [weak self] in
                self?.letterCaseController.handleShift()
            }
        )
        if updatedSymbolPage != symbolPage {
            symbolPage = updatedSymbolPage
        }
        if didHandle {
            updatePredictionAfterHandledKey(kind, activation: activation)
            updateActiveInsertionVisualState()
            synchronizeTypingKeyPresentation()
        }
        KeyboardTypingDiagnostics.log("controller_activation_end", fields: [
            "key": String(describing: kind),
            "handled": didHandle,
            "path": "text_input",
            "duration_ms": ((ProcessInfo.processInfo.systemUptime - startedAt) * 100_000)
                .rounded() / 100,
        ])
        return didHandle
    }

    @discardableResult
    func handleKeyActivation(_ kind: KeyboardKeyKind) -> Bool {
        handleKeyActivation(
            KeyboardKeyActivation(
                kind: kind,
                location: .zero,
                timestamp: ProcessInfo.processInfo.systemUptime,
                isLongPressAlternate: false
            )
        )
    }

    func handleSpaceTrackpadEvent(_ event: KeyboardSpaceTrackpadEvent) {
        switch event {
        case .began:
            isTrackpadModeActive = true
            cursorTrackpadInteractor.begin()
            updateUI()
        case let .moved(delta, timestamp):
            cursorTrackpadInteractor.handleMovement(
                delta: delta,
                timestamp: timestamp,
                adjustCursor: { [weak self] offset in
                    self?.textInputController.adjustCursorPosition(by: offset)
                }
            )
            updateActiveInsertionVisualState()
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
        guard let insertion = textInputController.insertTranscriptionWithResult(text) else {
            return
        }

        dictationChangeController.recordInsertedDictation(insertion)
        updateActiveInsertionVisualState()
        emitDelayedTranscriptionLandingHapticIfNeeded()
    }

    private func updateActiveInsertionVisualState() {
        rootContainerView?.vibesButton.title = dictationChangeController.displayedVibeTitle
        rootContainerView?.vibesButton.displayedVibeStyle = dictationChangeController.displayedVibeStyle
        rootContainerView?.vibesButton.isDisplayedVibeApplied = dictationChangeController.isDisplayedVibeAppliedToCurrentInsertion
        rootContainerView?.capsLockButton.isDictationCapsApplied = dictationChangeController.displayedCapsTransformApplied
        rootContainerView?.capsLockButton.isDictationCapsUppercase = dictationChangeController.displayedCapsTextIsUppercase
        rootContainerView?.paragraphButton.isOn = dictationChangeController.displayedAutoParagraphsEnabled
        rootContainerView?.listsButton.isOn = dictationChangeController.displayedListFormattingEnabled
    }

    private func handleDictationChangeProcessingStart() {
        interactionHaptics.emitMediumIfEnabled()
        indicatorDriver.phase = .processing
        rootContainerView?.logoBarView.applyIndicatorPhase(.processing)
    }

    private func handleDictationChangeProcessingEnd() {
        let phase = keyboardState.indicatorPhase
        indicatorDriver.phase = phase
        rootContainerView?.logoBarView.applyIndicatorPhase(phase)
    }

    private func handleDictationChangeResult(_ didApply: Bool) {
        if didApply {
            updateUI()
            interactionHaptics.emitSuccessIfEnabled()
        } else {
            interactionHaptics.emitMediumIfEnabled()
        }
    }

    private func updateTranscriptionLandingHapticStart(previousState: KeyboardState) {
        if keyboardState == .transcribing {
            if previousState != .transcribing {
                transcriptionLandingStartedAt = Date()
            }
            return
        }

        if previousState == .transcribing {
            transcriptionLandingStartedAt = nil
        }
    }

    private func emitDelayedTranscriptionLandingHapticIfNeeded() {
        guard let transcriptionLandingStartedAt else { return }
        self.transcriptionLandingStartedAt = nil

        guard Date().timeIntervalSince(transcriptionLandingStartedAt) > delayedTranscriptionLandingHapticThreshold else {
            return
        }

        interactionHaptics.emitMediumIfEnabled()
    }
}
