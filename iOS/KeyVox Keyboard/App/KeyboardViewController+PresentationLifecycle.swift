import Foundation
import UIKit

#if DEBUG
enum KeyboardPresentationLifecycleDiagnostics {
    static var createdPresentationViewTreeCount = 0
    static var destroyedPresentationViewTreeCount = 0

    static func reset() {
        createdPresentationViewTreeCount = 0
        destroyedPresentationViewTreeCount = 0
    }
}
#endif

extension KeyboardViewController {
    func preparePresentationIfNeeded() {
        ensurePresentationViews()
        activatePresentationBindingsIfNeeded()
    }

    func ensurePresentationViews() {
        guard rootContainerView == nil || popupOverlayView == nil else { return }

        if rootContainerView != nil || popupOverlayView != nil {
            tearDownPresentation()
        }

        let rootView = KeyboardRootView()
        rootView.translatesAutoresizingMaskIntoConstraints = false

        let popupOverlayView = UIView()
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

        self.rootContainerView = rootView
        self.popupOverlayView = popupOverlayView

#if DEBUG
        KeyboardPresentationLifecycleDiagnostics.createdPresentationViewTreeCount += 1
#endif
    }

    func activatePresentationBindingsIfNeeded() {
        guard isPresentationBound == false,
              let rootContainerView,
              let popupOverlayView else { return }

        rootContainerView.settingsButton.addTarget(self, action: #selector(handleSettingsTap), for: .touchUpInside)
        rootContainerView.cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
        rootContainerView.capsLockButton.addTarget(self, action: #selector(handleCapsLockTap), for: .touchUpInside)
        let capsLongPressRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleCapsLockLongPress(_:))
        )
        capsLongPressRecognizer.cancelsTouchesInView = true
        rootContainerView.capsLockButton.addGestureRecognizer(capsLongPressRecognizer)
        rootContainerView.paragraphButton.addTarget(self, action: #selector(handleParagraphsTap), for: .touchUpInside)
        rootContainerView.listsButton.addTarget(self, action: #selector(handleListsTap), for: .touchUpInside)
        rootContainerView.dictionaryButton.addTarget(self, action: #selector(handleDictionaryTap), for: .touchUpInside)
        rootContainerView.vibesButton.addTarget(self, action: #selector(handleVibesTap), for: .touchUpInside)
        let paragraphsLongPressRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleParagraphsLongPress(_:))
        )
        paragraphsLongPressRecognizer.cancelsTouchesInView = true
        rootContainerView.paragraphButton.addGestureRecognizer(paragraphsLongPressRecognizer)
        let listsLongPressRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleListsLongPress(_:))
        )
        listsLongPressRecognizer.cancelsTouchesInView = true
        rootContainerView.listsButton.addGestureRecognizer(listsLongPressRecognizer)
        let vibesLongPressRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleVibesLongPress(_:))
        )
        vibesLongPressRecognizer.cancelsTouchesInView = true
        rootContainerView.vibesButton.addGestureRecognizer(vibesLongPressRecognizer)
        rootContainerView.speakButton.addTarget(self, action: #selector(handleSpeakTap), for: .touchUpInside)
        rootContainerView.logoBarView.addTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
        rootContainerView.fullAccessInfoButton.addTarget(self, action: #selector(handleFullAccessInfoTap), for: .touchUpInside)
        rootContainerView.keyGridView.onKeyActivated = { [weak self] activation in
            self?.handleKeyActivation(activation) ?? false
        }
        rootContainerView.keyGridView.onDeleteWords = { [weak self] count in
            self?.handleDeleteWords(count) ?? false
        }
        rootContainerView.keyGridView.onCharacterKeyTouchDown = { [weak self] in
            self?.characterKeyHaptics.emitKeypressIfEnabled()
        }
        rootContainerView.keyGridView.onKeyTouchDown = { [weak self] activation in
            self?.prepareContestedTap(activation)
        }
        rootContainerView.keyGridView.onCharacterGeometryChange = { [weak self] geometry, size in
            self?.predictionCoordinator.updateGeometry(geometry, keyboardSize: size)
        }
        rootContainerView.suggestionBarView.onItemSelected = { [weak self] item in
            self?.handleSuggestionSelected(item)
        }
        rootContainerView.suggestionBarView.onItemLongPressed = { [weak self] item in
            self?.handleSuggestionLongPressed(item)
        }
        predictionCoordinator.onBarChange = { [weak self] bar in
            self?.rootContainerView?.suggestionBarView.apply(bar)
        }
        rootContainerView.keyGridView.onCompactKeysRequested = { [weak self] in
            self?.handleCompactKeysRequest() ?? false
        }
        rootContainerView.keyGridView.onSpaceTrackpadEvent = { [weak self] event in
            self?.handleSpaceTrackpadEvent(event)
        }
        rootContainerView.keyGridView.setPopupContainerView(popupOverlayView)

        indicatorDriver.sampleProvider = { [weak self] in
            self?.ipcManager.currentAudioIndicatorSample()
        }
        indicatorDriver.onUpdate = { [weak self] timelineState in
            guard let self else { return }
            self.rootContainerView?.logoBarView.applyTimelineState(timelineState)
            self.rootContainerView?.logoBarView.applyPlaybackProgress(self.ipcManager.currentTTSPlaybackProgress())
        }

        dictationController.registerObservers()
        isPresentationBound = true
    }

    func deactivatePresentationBindings() {
        guard isPresentationBound else { return }

        indicatorDriver.stop()
        indicatorDriver.sampleProvider = nil
        indicatorDriver.onUpdate = nil
        predictionCoordinator.onBarChange = nil
        rootContainerView?.logoBarView.applyPlaybackProgress(0)
        dictationController.unregisterObservers()

        if let rootContainerView {
            rootContainerView.settingsButton.removeTarget(self, action: #selector(handleSettingsTap), for: .touchUpInside)
            rootContainerView.cancelButton.removeTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
            rootContainerView.capsLockButton.removeTarget(self, action: #selector(handleCapsLockTap), for: .touchUpInside)
            rootContainerView.capsLockButton.gestureRecognizers?.forEach {
                rootContainerView.capsLockButton.removeGestureRecognizer($0)
            }
            rootContainerView.paragraphButton.removeTarget(self, action: #selector(handleParagraphsTap), for: .touchUpInside)
            rootContainerView.listsButton.removeTarget(self, action: #selector(handleListsTap), for: .touchUpInside)
            rootContainerView.paragraphButton.gestureRecognizers?.forEach {
                rootContainerView.paragraphButton.removeGestureRecognizer($0)
            }
            rootContainerView.listsButton.gestureRecognizers?.forEach {
                rootContainerView.listsButton.removeGestureRecognizer($0)
            }
            rootContainerView.dictionaryButton.removeTarget(self, action: #selector(handleDictionaryTap), for: .touchUpInside)
            rootContainerView.vibesButton.removeTarget(self, action: #selector(handleVibesTap), for: .touchUpInside)
            rootContainerView.vibesButton.gestureRecognizers?.forEach {
                rootContainerView.vibesButton.removeGestureRecognizer($0)
            }
            rootContainerView.speakButton.removeTarget(self, action: #selector(handleSpeakTap), for: .touchUpInside)
            rootContainerView.logoBarView.removeTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
            rootContainerView.fullAccessInfoButton.removeTarget(self, action: #selector(handleFullAccessInfoTap), for: .touchUpInside)
            rootContainerView.keyGridView.onKeyActivated = nil
            rootContainerView.keyGridView.onDeleteWords = nil
            rootContainerView.keyGridView.onCharacterKeyTouchDown = nil
            rootContainerView.keyGridView.onKeyTouchDown = nil
            rootContainerView.keyGridView.onCharacterGeometryChange = nil
            rootContainerView.suggestionBarView.onItemSelected = nil
            rootContainerView.suggestionBarView.onItemLongPressed = nil
            rootContainerView.keyGridView.onCompactKeysRequested = nil
            rootContainerView.keyGridView.onSpaceTrackpadEvent = nil
            rootContainerView.keyGridView.setPopupContainerView(nil)
            rootContainerView.keyGridView.resetInteractionState()
        }

        fullAccessView?.onBack = nil
        primaryHeightConstraint?.isActive = false
        primaryHeightConstraint = nil
        isPresentationBound = false
    }

    func destroyPresentationViews() {
        let hadPresentationViews = fullAccessView != nil || popupOverlayView != nil || rootContainerView != nil

        if let fullAccessView {
            fullAccessView.removeFromSuperview()
            self.fullAccessView = nil
        }

        if let popupOverlayView {
            popupOverlayView.subviews.forEach { $0.removeFromSuperview() }
            popupOverlayView.removeFromSuperview()
            self.popupOverlayView = nil
        }

        if let rootContainerView {
            rootContainerView.removeFromSuperview()
            self.rootContainerView = nil
        }

#if DEBUG
        if hadPresentationViews {
            KeyboardPresentationLifecycleDiagnostics.destroyedPresentationViewTreeCount += 1
        }
#endif
    }

    func tearDownPresentation() {
        deactivatePresentationBindings()
        destroyPresentationViews()
    }

    func configureHostLifecycleObservers() {
        guard hostWillResignActiveObserver == nil, hostDidBecomeActiveObserver == nil else { return }

        hostWillResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSExtensionHostWillResignActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.extensionHostIsActive = false
            self?.rootContainerView?.keyGridView.resetInteractionState()
            self?.indicatorDriver.stop()
        }

        hostDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSExtensionHostDidBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.extensionHostIsActive = true
            guard let self else { return }
            KeyboardTypingMemory.shared.adoptResetIfNeeded()
            self.preparePresentationIfNeeded()
            self.installedModels = KeyboardInstalledModels.check()
            self.configurePrimaryViewHeight()
            self.syncCapsLockState()
            self.rootContainerView?.keyGridView.resetInteractionState()
            self.dictationController.syncStateFromSharedState()
            self.ttsController.syncStateFromSharedState()
            self.indicatorDriver.start()
            KeyVoxIPCBridge.reportKeyboardOnboardingState(hasFullAccess: self.hasFullAccess)
            KeyVoxIPCBridge.reportKeyboardOnboardingPresentation()
            self.updateUI()
        }
    }

    func removeHostLifecycleObservers() {
        if let hostWillResignActiveObserver {
            NotificationCenter.default.removeObserver(hostWillResignActiveObserver)
            self.hostWillResignActiveObserver = nil
        }

        if let hostDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(hostDidBecomeActiveObserver)
            self.hostDidBecomeActiveObserver = nil
        }
    }
}
