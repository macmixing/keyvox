import KeyVoxPredictiveKeyboard
import UIKit

/// Multi-finger key handling.
///
/// Each finger is followed separately. A character types when its finger lifts, or as
/// soon as another finger lands (rollover), so overlapping two-thumb taps always type in
/// the order they landed. Delete repeats while held, as the system keyboard's does, even once
/// the finger slides off it; a held space bar becomes a cursor trackpad, holding the
/// alternate-symbols key opens Compact Keys, and holding a key that offers more characters, such
/// as accented letters, opens their popup, where the finger picks one.
extension KeyboardKeyGridView {
    func configureTouchRouter() {
        touchRouter.onTouchesBegan = { [weak self] touches in
            self?.handleTouchesBegan(touches)
        }
        touchRouter.onTouchesMoved = { [weak self] touches in
            self?.handleTouchesMoved(touches)
        }
        touchRouter.onTouchesEnded = { [weak self] touches in
            self?.handleTouchesEnded(touches)
        }
        touchRouter.onTouchesCancelled = { [weak self] touches in
            self?.handleTouchesCancelled(touches)
        }
        addGestureRecognizer(touchRouter)
    }

    func cancelAllTouches() {
        let hadTrackpad = spaceTrackpadController.cancel()
        trackpadOriginKeyView = nil
        compactKeysHoldController.cancel()
        deleteRepeatController.cancel()
        cancelHeldKey()
        touchSessions.removeAll()
        popupOwnerKeyView = nil
        popupView.dismiss()
        if hadTrackpad {
            onSpaceTrackpadEvent?(.cancelled)
        }
    }

    private func handleTouchesBegan(_ touches: Set<UITouch>) {
        guard isKeyboardEnabled else { return }
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            let location = touch.location(in: self)
            typePendingCharacters()

            let hitKey = keyView(at: location)
            let session = KeyboardKeyTouchSession(
                keyView: hitKey,
                location: location,
                timestamp: touch.timestamp
            )
            touchSessions[ObjectIdentifier(touch)] = session
            guard let hitKey else { continue }
            setVisualState(.pressed, for: hitKey)
            onKeyTouchDown?(activation(hitKey.model.kind, from: session))

            switch hitKey.model.kind {
            case .character:
                showPopup(for: hitKey)
                beginHeldKey(for: session)
            case .delete:
                var isRepeat = false
                deleteRepeatController.begin { [weak self, weak session] granularity in
                    guard let self, let session else { return false }
                    defer { isRepeat = true }
                    if case let .words(count) = granularity, self.onDeleteWords?(count) == true {
                        return true
                    }
                    return self.deliver(.delete, from: session, isRepeat: isRepeat)
                }
            case .space:
                trackpadOriginKeyView = hitKey
                trackpadActivationFeedback.prepare()
                spaceTrackpadController.begin(onSpaceKey: true, location: location) { [weak self] in
                    self?.activateSpaceTrackpad()
                }
            case .alternateSymbols:
                compactKeysHoldController.begin(onCompactKeysTrigger: true) { [weak self] in
                    self?.onCompactKeysRequested?() ?? false
                }
            default:
                break
            }
        }
    }

    private func handleTouchesMoved(_ touches: Set<UITouch>) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        for touch in touches {
            guard let session = touchSessions[ObjectIdentifier(touch)] else { continue }
            let location = touch.location(in: self)
            switch session.kind {
            case .delete:
                continue
            case .space:
                let update = spaceTrackpadController.update(
                    location: location,
                    isStillOnSpaceKey: spaceTrackpadController.isActive
                        || keyView(at: location)?.model.kind == .space
                )
                if spaceTrackpadController.isActive, let movementDelta = update.movementDelta {
                    onSpaceTrackpadEvent?(.moved(movementDelta, timestamp: timestamp))
                }
            case .alternateSymbols:
                compactKeysHoldController.update(
                    isStillOnCompactKeysTrigger: keyView(at: location, hitSlop: 0)?.model.kind
                        == .alternateSymbols
                )
            default:
                if session === heldKeyTouchSession, heldKeyController.hasOpened {
                    followHeldKey(to: location)
                    continue
                }
                guard session.hasTyped == false,
                      let hitKey = keyView(at: location),
                      hitKey !== session.keyView,
                      hitKey.model.isSpecialKey == false || session.kind.map(Self.isCharacter) == false else {
                    continue
                }
                if let previousKey = session.keyView {
                    setVisualState(.normal, for: previousKey)
                }
                session.keyView = hitKey
                session.activationLocation = location
                setVisualState(.pressed, for: hitKey)
                if case .character = hitKey.model.kind {
                    showPopup(for: hitKey)
                    beginHeldKey(for: session)
                } else {
                    dismissPopup(ownedBy: popupOwnerKeyView)
                    if session === heldKeyTouchSession {
                        cancelHeldKey()
                    }
                }
            }
        }
    }

    private func handleTouchesEnded(_ touches: Set<UITouch>) {
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let session = touchSessions.removeValue(forKey: ObjectIdentifier(touch)) else {
                continue
            }
            if let keyView = session.keyView, isStillPressed(keyView) == false {
                setVisualState(.normal, for: keyView)
            }
            dismissPopup(ownedBy: session.keyView)
            if session === heldKeyTouchSession {
                deliverHeldKey(from: session)
                continue
            }

            switch session.kind {
            case .delete:
                deleteRepeatController.cancel()
                onDeleteKeyUp?()
            case .alternateSymbols:
                if compactKeysHoldController.end() == false {
                    deliver(.alternateSymbols, from: session)
                }
            case .space:
                let wasTrackpadActive = spaceTrackpadController.end()
                trackpadOriginKeyView = nil
                if wasTrackpadActive {
                    updateAllKeyStates()
                    onSpaceTrackpadEvent?(.ended)
                } else {
                    deliver(.space, from: session)
                }
            case let .some(kind):
                guard session.hasTyped == false else { continue }
                deliver(kind, from: session)
            case .none:
                continue
            }
        }
    }

    private func handleTouchesCancelled(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let session = touchSessions.removeValue(forKey: ObjectIdentifier(touch)) else {
                continue
            }
            if let keyView = session.keyView, isStillPressed(keyView) == false {
                setVisualState(.normal, for: keyView)
            }
            dismissPopup(ownedBy: session.keyView)
            if session === heldKeyTouchSession {
                cancelHeldKey()
            }
            switch session.kind {
            case .delete:
                deleteRepeatController.cancel()
            case .alternateSymbols:
                compactKeysHoldController.cancel()
            case .space:
                let wasTrackpadActive = spaceTrackpadController.cancel()
                trackpadOriginKeyView = nil
                if wasTrackpadActive {
                    updateAllKeyStates()
                    onSpaceTrackpadEvent?(.cancelled)
                }
            default:
                break
            }
        }
    }

    /// Types every character still held down, in the order the fingers landed, before a
    /// new finger's key counts.
    private func typePendingCharacters() {
        let pending = touchSessions.values
            .filter(\.isPendingCharacter)
            .sorted { $0.timestamp < $1.timestamp }
        for session in pending {
            session.hasTyped = true
            if session === heldKeyTouchSession {
                deliverHeldKey(from: session)
            } else if let kind = session.kind {
                deliver(kind, from: session)
            }
        }
    }

    @discardableResult
    private func deliver(
        _ kind: KeyboardKeyKind,
        from session: KeyboardKeyTouchSession,
        isRepeat: Bool = false,
        isHeldKeyChoice: Bool = false
    ) -> Bool {
        if case .character = kind {
            onCharacterKeyTyped?()
        }
        return onKeyActivated?(activation(kind, from: session, isRepeat: isRepeat, isHeldKeyChoice: isHeldKeyChoice)) ?? false
    }

    private func activation(
        _ kind: KeyboardKeyKind,
        from session: KeyboardKeyTouchSession,
        isRepeat: Bool = false,
        isHeldKeyChoice: Bool = false
    ) -> KeyboardKeyActivation {
        KeyboardKeyActivation(
            kind: kind,
            location: session.activationLocation,
            keyFrame: session.keyView.map { $0.convert($0.bounds, to: self) } ?? .null,
            timestamp: session.timestamp,
            isRepeat: isRepeat,
            isHeldKeyChoice: isHeldKeyChoice
        )
    }

    /// Starts timing the finger on its key when the key offers characters when held.
    private func beginHeldKey(for session: KeyboardKeyTouchSession) {
        cancelHeldKey()
        guard case let .character(value) = session.kind,
              let offer = heldKeyController.offer(forKey: value),
              let keyView = session.keyView else {
            return
        }
        heldKeyTouchSession = session
        heldKeyController.begin { [weak self, weak keyView] in
            guard let self, let keyView else { return nil }
            return self.openHeldKeyPopup(offer, from: keyView)
        }
    }

    /// Shows the popup in place of the key's bubble and returns its layout.
    private func openHeldKeyPopup(_ offer: HeldKeyCharacters.Offer, from keyView: KeyboardKeyView) -> HeldKeyPopupLayout {
        let container = popupContainerView ?? self
        let isLandscape = window?.windowScene?.interfaceOrientation.isLandscape ?? false
        let metrics = HeldKeyPopupLayout.Metrics(
            cellWidth: keyView.bounds.width + KeyboardStyle.keySpacing - KeyboardStyle.heldKeyPopupCellWidthReduction,
            cellHeight: KeyboardStyle.heldKeyPopupCellHeight,
            padding: KeyboardStyle.heldKeyPopupPadding,
            gapAboveKey: isLandscape ? KeyboardStyle.landscapeHeldKeyPopupGapAboveKey : KeyboardStyle.heldKeyPopupGapAboveKey,
            closingDistance: isLandscape
                ? KeyboardStyle.landscapeHeldKeyPopupClosingDistance
                : KeyboardStyle.heldKeyPopupClosingDistance
        )
        let layout = HeldKeyPopupLayout(
            offer: offer,
            keyFrame: keyView.convert(keyView.bounds, to: container),
            bounds: container.bounds,
            metrics: metrics
        )
        dismissPopup(ownedBy: popupOwnerKeyView)
        heldKeyPopupView.present(layout, in: container)
        onHeldKeyPopupOpened?()
        return layout
    }

    private func followHeldKey(to location: CGPoint) {
        let container = popupContainerView ?? self
        switch heldKeyController.update(location: convert(location, to: container)) {
        case .unchanged:
            break
        case let .selected(cell):
            heldKeyPopupView.select(cell)
        case .closed:
            heldKeyPopupView.dismiss()
        }
    }

    /// Types what the held key's finger picked: the key itself when the popup never opened,
    /// the character it lifted on, or nothing once it closed the popup.
    private func deliverHeldKey(from session: KeyboardKeyTouchSession) {
        let outcome = heldKeyController.end()
        heldKeyTouchSession = nil
        heldKeyPopupView.dismiss()
        switch outcome {
        case .notOpened:
            if let kind = session.kind {
                deliver(kind, from: session)
            }
        case let .chose(character):
            deliver(.character(character), from: session, isHeldKeyChoice: true)
        case .closed:
            break
        }
    }

    func cancelHeldKey() {
        heldKeyController.cancel()
        heldKeyTouchSession = nil
        heldKeyPopupView.dismiss()
    }

    private func activateSpaceTrackpad() {
        guard trackpadOriginKeyView != nil else { return }
        trackpadActivationFeedback.impactOccurred()
        trackpadActivationFeedback.prepare()
        dismissPopup(ownedBy: popupOwnerKeyView)
        updateAllKeyStates()
        onSpaceTrackpadEvent?(.began)
    }

    private func showPopup(for keyView: KeyboardKeyView) {
        guard keyView.model.allowsPopup, let text = keyView.model.popupText else {
            dismissPopup(ownedBy: popupOwnerKeyView)
            return
        }
        popupOwnerKeyView = keyView
        popupView.present(text: text, from: keyView, in: popupContainerView ?? self)
    }

    private func dismissPopup(ownedBy keyView: KeyboardKeyView?) {
        guard let keyView, keyView === popupOwnerKeyView else { return }
        popupOwnerKeyView = nil
        popupView.dismiss()
    }

    private func isStillPressed(_ keyView: KeyboardKeyView) -> Bool {
        touchSessions.values.contains { $0.keyView === keyView }
    }

    nonisolated private static func isCharacter(_ kind: KeyboardKeyKind) -> Bool {
        if case .character = kind { return true }
        return false
    }
}
