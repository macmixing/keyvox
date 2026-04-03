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

        rootContainerView.cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
        rootContainerView.capsLockButton.addTarget(self, action: #selector(handleCapsLockTap), for: .touchUpInside)
        rootContainerView.speakButton.addTarget(self, action: #selector(handleSpeakTap), for: .touchUpInside)
        rootContainerView.logoBarView.addTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
        rootContainerView.fullAccessInfoButton.addTarget(self, action: #selector(handleFullAccessInfoTap), for: .touchUpInside)
        rootContainerView.keyGridView.onKeyActivated = { [weak self] kind in
            self?.handleKeyActivation(kind) ?? false
        }
        rootContainerView.keyGridView.onSpaceTrackpadEvent = { [weak self] event in
            self?.handleSpaceTrackpadEvent(event)
        }
        rootContainerView.keyGridView.setPopupContainerView(popupOverlayView)

        indicatorDriver.sampleProvider = { [weak self] in
            self?.ipcManager.currentAudioIndicatorSample()
        }
        indicatorDriver.onUpdate = { [weak self] timelineState in
            self?.rootContainerView?.logoBarView.applyTimelineState(timelineState)
        }

        dictationController.registerObservers()
        isPresentationBound = true
    }

    func deactivatePresentationBindings() {
        guard isPresentationBound else { return }

        indicatorDriver.stop()
        indicatorDriver.sampleProvider = nil
        indicatorDriver.onUpdate = nil
        dictationController.unregisterObservers()

        if let rootContainerView {
            rootContainerView.cancelButton.removeTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
            rootContainerView.capsLockButton.removeTarget(self, action: #selector(handleCapsLockTap), for: .touchUpInside)
            rootContainerView.speakButton.removeTarget(self, action: #selector(handleSpeakTap), for: .touchUpInside)
            rootContainerView.logoBarView.removeTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
            rootContainerView.fullAccessInfoButton.removeTarget(self, action: #selector(handleFullAccessInfoTap), for: .touchUpInside)
            rootContainerView.keyGridView.onKeyActivated = nil
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
            self.preparePresentationIfNeeded()
            self.configurePrimaryViewHeight()
            self.syncCapsLockState()
            self.callObserver.refreshState()
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
