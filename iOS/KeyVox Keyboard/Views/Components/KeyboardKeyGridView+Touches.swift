import UIKit

/// Multi-finger key handling.
///
/// Each finger is followed separately. A character types when its finger lifts, or as
/// soon as another finger lands (rollover), so overlapping two-thumb taps always type in
/// the order they landed. Delete repeats while held, as the system keyboard's does, even once
/// the finger slides off it; a held space bar becomes a cursor trackpad, and holding the
/// alternate-symbols key opens Compact Keys.
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
                onCharacterKeyTouchDown?()
                showPopup(for: hitKey)
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
                } else {
                    dismissPopup(ownedBy: popupOwnerKeyView)
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

            switch session.kind {
            case .delete:
                deleteRepeatController.cancel()
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
            if let kind = session.kind {
                deliver(kind, from: session)
            }
        }
    }

    @discardableResult
    private func deliver(
        _ kind: KeyboardKeyKind,
        from session: KeyboardKeyTouchSession,
        isRepeat: Bool = false
    ) -> Bool {
        onKeyActivated?(activation(kind, from: session, isRepeat: isRepeat)) ?? false
    }

    private func activation(
        _ kind: KeyboardKeyKind,
        from session: KeyboardKeyTouchSession,
        isRepeat: Bool = false
    ) -> KeyboardKeyActivation {
        KeyboardKeyActivation(
            kind: kind,
            location: session.activationLocation,
            keyFrame: session.keyView.map { $0.convert($0.bounds, to: self) } ?? .null,
            timestamp: session.timestamp,
            isRepeat: isRepeat
        )
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
