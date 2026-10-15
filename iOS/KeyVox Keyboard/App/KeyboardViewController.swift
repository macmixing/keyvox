import AVFoundation
import KeyVoxCore
import KeyVoxEmoji
import KeyVoxPredictiveKeyboard
import UIKit

final class KeyboardViewController: UIInputViewController {
    let ipcManager = KeyboardIPCManager()
    let capsLockStateStore = KeyboardCapsLockStateStore()
    let keypressHaptics = KeyboardKeypressHaptics()
    /// The tap felt on letter and character keys, the system keyboard's text input tap.
    let characterKeyHaptics = KeyboardKeypressHaptics(generator: KeyboardTextInputHapticPlayer())
    let interactionHaptics = KeyboardInteractionHaptics()
    let indicatorDriver = AudioIndicatorDriver()
    let appSettingsStore = KeyboardAppSettingsStore()
    let startRecordingURL = URL(string: "keyvoxios://record/start")
    let startTTSURL = URL(string: "keyvoxios://tts/start")
    let openDictionaryURL = URL(string: "keyvoxios://tab/dictionary")
    let openSettingsURL = URL(string: "keyvoxios://tab/settings")
    let openVibesURL = URL(string: "keyvoxios://vibes/open")
    let openVibesModelRecoveryURL = URL(string: "keyvoxios://vibes/model-recovery")
    let delayedTranscriptionLandingHapticThreshold: TimeInterval = 1
    let dictionaryCasingStore = KeyboardDictionaryCasingStore()
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
        },
        isPeriodShortcutEnabled: { [weak self] in
            self?.typingTraits.allowsPeriodShortcut ?? true
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
        startRecordingURL: startRecordingURL,
        isAudioCaptureAvailable: {
            let audioSession = AVAudioSession.sharedInstance()
            let currentAudioConflict = audioSession.isOtherAudioPlaying
                && audioSession.secondaryAudioShouldBeSilencedHint
            return !currentAudioConflict
        }
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
    let letterCaseController = KeyboardLetterCaseController()
    var symbolPageReturnTracker = KeyboardSymbolPageReturnTracker()
    /// Checked when the keyboard comes on screen; see `KeyboardInstalledModels`.
    var installedModels = KeyboardInstalledModels.check()
    lazy var predictionCoordinator = KeyboardPredictionCoordinator(
        memory: KeyboardTypingMemory.shared.memory,
        textBeforeCursor: { [weak self] in self?.textDocumentProxy.documentContextBeforeInput },
        selectedText: { [weak self] in self?.textDocumentProxy.selectedText },
        textAfterCursor: { [weak self] in self?.textDocumentProxy.documentContextAfterInput }
    )
    var typingTraits = KeyboardTypingTraits.standard
    /// Whether the keyboard appeared and has yet to read the field, which waits for the system to
    /// hand over the field's document state.
    var awaitsFieldState = false
    /// The user's KeyVox Dictionary, contact names, and text replacements, without what the
    /// keyboard learned from their typing.
    var userVocabulary = PersonalVocabulary.empty
    /// The system's names and text replacements, as last sent (`loadPersonalVocabulary`).
    var supplementaryLexicon: UILexicon?
    var primaryHeightConstraint: NSLayoutConstraint?
    var keyboardState: KeyboardState = .idle {
        didSet {
            updateTranscriptionLandingHapticStart(previousState: oldValue)
            updateUI()
        }
    }
    var symbolPage: KeyboardSymbolPage = .letters {
        didSet {
            updateUI()
        }
    }
    var keysMode: KeyboardKeysMode = .full {
        didSet {
            guard keysMode != oldValue else { return }
            updatePrimaryViewHeight()
            updateUI()
        }
    }
    /// Whether the screen is in landscape, read on each layout pass; keys are shorter there.
    var isLandscape = false {
        didSet {
            guard isLandscape != oldValue else { return }
            updatePrimaryViewHeight()
            updateUI()
        }
    }
    /// Whether the keys show the globe, read on each layout pass: the system shows none under the
    /// keyboard on an iPhone with a Home button.
    var showsNextKeyboardKey = false {
        didSet {
            guard showsNextKeyboardKey != oldValue else { return }
            updateUI()
        }
    }
    var isCapsLockEnabled = false {
        didSet {
            updateUI()
        }
    }
    /// Whether the focused field holds any letters, read only as the field is set up or its
    /// text changes. Until it does, the dictation tools show in place of suggestions.
    var fieldHasLetters = false {
        didSet {
            guard fieldHasLetters != oldValue else { return }
            updateUI()
        }
    }
    /// What the emoji key opened: the emoji page in the key grid's place, or its search over the
    /// letter keys, which makes the keyboard taller; the toolbar offers no suggestions while either
    /// shows.
    var emojiPanel: KeyboardEmojiPanel = .closed {
        didSet {
            guard emojiPanel != oldValue else { return }
            // The emoji page shows at the full keyboard's size, even from Compact Keys.
            updatePrimaryViewHeight()
            updateUI()
        }
    }
    /// What the emoji search searches for.
    var emojiSearchText = ""
    /// The emoji the search shows before anything is typed: the Frequently Used emoji as the page
    /// showed them when the search opened.
    var emojiSearchFrequentlyUsed: [Emoji] = []
    let emojiDeleteRepeatController = KeyboardDeleteRepeatController()
    let emojiFrequentlyUsedStore = KeyboardEmojiFrequentlyUsedStore()
    let emojiSkinToneStore = KeyboardEmojiSkinToneStore()
    /// Whether the last dictation is still as it landed, so the toolbar offers the dictation
    /// buttons, such as Vibes, to change it in place of suggestions.
    var isLastDictationUntouched = false {
        didSet {
            guard isLastDictationUntouched != oldValue else { return }
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
        KeyboardTypingMemory.shared.onLearnedVocabularyChange = { [weak self] in
            self?.learnedVocabularyDidChange()
        }
        KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: hasFullAccess)
        appSettingsStore.normalizeSelectedVibeIfNeeded()
        syncCapsLockState()
        dictationController.syncStateFromSharedState()
        ttsController.syncStateFromSharedState()
        updateUI()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        isLandscape = view.window?.windowScene?.interfaceOrientation.isLandscape ?? false
        showsNextKeyboardKey = needsInputModeSwitchKey
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        extensionHostIsActive = true
        KeyboardTypingMemory.shared.adoptResetIfNeeded()
        // Opens as the user's settings say until the field is read, which can still ask for 123.
        applyOpeningLayout(prefersNumberPage: appSettingsStore.opensOnNumberPage)
        // The field is read once the system hands over its document state, which it ends with
        // `textDidChange(_:)`: as a field connects, the system replaces the document state off
        // the main thread, frees the old one, and waits on the main thread to hand over the
        // new one, so a read before then, even on a later main-thread turn, can reach freed
        // memory.
        awaitsFieldState = true
        preparePresentationIfNeeded()
        installedModels = KeyboardInstalledModels.check()
        KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: hasFullAccess)
        configureDictationBehavior()
        rootContainerView?.keyGridView.resetInteractionState()
        appSettingsStore.normalizeSelectedVibeIfNeeded()
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

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        if awaitsFieldState, rootContainerView != nil {
            awaitsFieldState = false
            prepareTypingForCurrentField()
            return
        }
        handleTypingContextChange()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        handleTypingContextChange()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // The system keyboard ends its emoji search when it goes away.
        leaveEmojiSearch()
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

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
        primaryHeightConstraint = heightConstraint
    }

    private func updatePrimaryViewHeight() {
        guard let primaryHeightConstraint else { return }
        primaryHeightConstraint.constant = keyboardHeight
        view.setNeedsLayout()
    }

    /// The keys mode the keyboard lays out in: full while the emoji page or its search shows,
    /// Compact Keys staying the user's mode underneath to return to.
    private var layoutKeysMode: KeyboardKeysMode {
        emojiPanel == .closed ? keysMode : .full
    }

    /// The keyboard's height, taller by the search results while searching emoji.
    private var keyboardHeight: CGFloat {
        layoutKeysMode.keyboardHeight(isLandscape: isLandscape)
            + (emojiPanel == .searching ? KeyboardEmojiSearchGeometry.addedKeyboardHeight : 0)
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
            guard let self else { return }
            let isPresentingTTS = state == .preparingPlayback || state.isTTSPlaybackActive
            let wasPresentingTTS = self.keyboardState == .preparingPlayback
                || self.keyboardState.isTTSPlaybackActive
            guard isPresentingTTS || wasPresentingTTS else { return }
            self.keyboardState = state
        }
        dictationController.onTranscriptionReady = { [weak self] text in
            self?.handleTranscriptionReady(text)
        }
    }

    func updateUI() {
        if appSettingsStore.isCompactKeysEnabled == false {
            if appSettingsStore.isCompactKeysActive {
                appSettingsStore.setCompactKeysActive(false)
            }
            if keysMode == .compact {
                keysMode = .full
                return
            }
        }
        if appSettingsStore.isEmojiKeyboardEnabled == false, emojiPanel != .closed {
            emojiPanel = .closed
            return
        }

        let toolbarMode = currentToolbarMode()
        rootContainerView?.emojiPageView.returnKey = emojiPageReturnKey
        rootContainerView?.apply(
            state: keyboardState,
            symbolPage: symbolPage,
            keysMode: layoutKeysMode,
            isLandscape: isLandscape,
            offersPredictions: typingTraits.showsSuggestions && fieldHasLetters && isLastDictationUntouched == false
                && emojiPanel == .closed,
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
            toolbarMode: toolbarMode,
            emojiPanel: emojiPanel,
            showsEmojiKey: appSettingsStore.isEmojiKeyboardEnabled,
            showsNextKeyboardKey: showsNextKeyboardKey,
            isTTSReady: installedModels.isTTSReady,
            isTrackpadModeActive: isTrackpadModeActive
        )
        applyLetterCase()
        if toolbarMode != .fullAccessWarning {
            setFullAccessInstructionsPresented(false)
        }
        indicatorDriver.phase = keyboardState.indicatorPhase
        indicatorDriver.isPlaybackActive = keyboardState.isTTSPlaybackActive
    }

    private func currentToolbarMode() -> KeyboardToolbarMode {
        KeyboardToolbarMode.resolve(
            modelAvailability: installedModels.dictation,
            hasFullAccess: hasFullAccess,
            hasMicrophonePermission: hasMicrophonePermission
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
        case .idle, .waitingForApp, .dictationStartFailed, .preparingPlayback, .recording, .transcribing:
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
            containingAppLauncher.open(openVibesModelRecoveryURL)
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
    func handleCompactKeysRequest() -> Bool {
        guard appSettingsStore.isCompactKeysEnabled,
              keysMode == .full,
              symbolPage == .primary,
              emojiPanel != .searching else {
            return false
        }

        appSettingsStore.setCompactKeysActive(true)
        keysMode = .compact
        interactionHaptics.emitSuccessIfEnabled()
        return true
    }

    @discardableResult
    func handleKeyActivation(_ keyActivation: KeyboardKeyActivation) -> Bool {
        if emojiPanel == .searching, let handled = handleEmojiSearchActivation(keyActivation) {
            return handled
        }
        let activation = resolveContestedTap(keyActivation)
        let kind = activation.kind
        if kind == .emoji {
            openEmojiPage()
            return true
        }
        if kind == .restoreFullKeyboard {
            guard keysMode == .compact else { return false }
            appSettingsStore.setCompactKeysActive(false)
            keysMode = .full
            interactionHaptics.emitMediumIfEnabled()
            return true
        }
        // ABC shows the full letter keys without turning Compact Keys off, so 123 returns to them.
        if kind == .abc, keysMode == .compact {
            keysMode = .full
        }
        if kind == .numberSymbols, symbolPage == .letters, emojiPanel != .searching,
           KeyboardKeysMode.resolve(
               isCompactKeysEnabled: appSettingsStore.isCompactKeysEnabled,
               isCompactKeysActive: appSettingsStore.isCompactKeysActive
           ) == .compact {
            keysMode = .compact
        }
        updateSymbolPage(for: kind)
        if let handled = handleTypingActivation(activation) {
            return handled
        }

        var updatedSymbolPage = symbolPage
        let didHandle = textInputController.handleKeyActivation(
            kind,
            typesExactly: activation.isHeldKeyChoice,
            // The delete key's press plays its haptic when the finger lifts; repeats play theirs now.
            emitsKeypress: kind != .delete || activation.isRepeat,
            symbolPage: &updatedSymbolPage
        )
        // Setting the page redraws the whole keyboard, so only a key that changed it sets it.
        if updatedSymbolPage != symbolPage {
            symbolPage = updatedSymbolPage
        }
        if didHandle {
            recordTypedCharacter(activation)
            handleTypingContextChange()
        }
        return didHandle
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
            handleTypingContextChange()
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
        let artifactID = KeyVoxIPCBridge.latestTranscriptionID()
        let styleIdentifier = KeyVoxIPCBridge.latestTranscriptionStyleIdentifier()
        guard let insertion = textInputController.insertTranscriptionWithResult(text) else {
            return
        }

        dictationChangeController.recordInsertedDictation(
            insertion,
            artifactID: artifactID,
            styleIdentifier: styleIdentifier
        )
        handleTypingContextChange()
        emitDelayedTranscriptionLandingHapticIfNeeded()
    }

    func updateActiveInsertionVisualState() {
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
        // A change that could not apply stops tracking the dictation.
        isLastDictationUntouched = dictationChangeController.hasActiveUntouchedInsertion
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
