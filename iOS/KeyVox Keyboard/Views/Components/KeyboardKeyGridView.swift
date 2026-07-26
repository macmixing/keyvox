import UIKit

enum KeyboardTopRowAccessorySlot: Int {
    case one = 0
    case two = 1
    case three = 2
    case four = 3
    case five = 4
    case six = 5
    case seven = 6
    case eight = 7
    case nine = 8
    case zero = 9
}

final class KeyboardKeyGridView: UIView {
    private static let completedTouchRetentionDuration: TimeInterval = 0.5

    private struct CompletedRoutedTouch: Equatable {
        let beganAt: TimeInterval
        let endedAt: TimeInterval

        func contains(timestamp: TimeInterval) -> Bool {
            timestamp == beganAt || timestamp == endedAt
        }
    }

    private final class TouchSession {
        let diagnosticIdentifier: Int
        let beganAt: TimeInterval
        let beganLocation: CGPoint
        let initialKeyView: KeyboardKeyView?
        var currentKeyView: KeyboardKeyView?
        var alternatePresentationWorkItem: DispatchWorkItem?
        var popupPresentedAt: TimeInterval?
        var lastMovementTimestamp: TimeInterval

        init(
            diagnosticIdentifier: Int,
            beganAt: TimeInterval,
            beganLocation: CGPoint,
            currentKeyView: KeyboardKeyView?
        ) {
            self.diagnosticIdentifier = diagnosticIdentifier
            self.beganAt = beganAt
            self.beganLocation = beganLocation
            self.initialKeyView = currentKeyView
            self.currentKeyView = currentKeyView
            self.lastMovementTimestamp = beganAt
        }
    }

    var onKeyActivated: ((KeyboardKeyActivation) -> Bool)?
    var onSpaceTrackpadEvent: ((KeyboardSpaceTrackpadEvent) -> Void)?
    var onCharacterGeometryChange: (([KeyboardCharacterKeyGeometry], CGSize) -> Void)?

    private let rowsStack = UIStackView()
    private let popupView = KeyboardKeyPopupView()
    private let alternatePopupView = KeyboardAlternateCharacterPopupView()
    private var keyViews: [KeyboardKeyView] = []
    private var touchSessions: [ObjectIdentifier: TouchSession] = [:]
    private var recentlyCompletedRoutedTouches: [ObjectIdentifier: CompletedRoutedTouch] = [:]
    private(set) var symbolPage: KeyboardSymbolPage = .alphabetic
    private var letterCase: KeyboardLetterCase = .shifted
    private var isKeyboardEnabled = true
    private weak var activeKeyView: KeyboardKeyView?
    private weak var popupContainerView: UIView?
    private weak var trackpadOriginKeyView: KeyboardKeyView?
    private let spaceTrackpadController = KeyboardSpaceTrackpadController()
    private let trackpadActivationFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var deleteRepeatController = KeyboardDeleteRepeatController()
    private var isDeleteTouchConsuming = false
    private var deleteTouchIdentifier: ObjectIdentifier?
    private var spaceTouchIdentifier: ObjectIdentifier?
    private var alternateTouchIdentifier: ObjectIdentifier?
    private var lastTouchBeganAt: TimeInterval?
    private var lastTouchEndedAt: TimeInterval?
    private var lastActivationAt: TimeInterval?
    private var lastReportedCharacterGeometry: [KeyboardCharacterKeyGeometry] = []
    private var secondRowLayoutGeometry: KeyboardLayoutGeometry.SecondRowLayout?
    private var thirdRowLayoutGeometry: KeyboardLayoutGeometry.ThirdRowLayout?
    private var bottomRowLayoutGeometry: KeyboardLayoutGeometry.BottomRowLayout?
    private var touchRouter: KeyboardTouchRouterGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        rebuildKeys(for: symbolPage)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSymbolPage(_ page: KeyboardSymbolPage) {
        guard page != symbolPage else { return }
        symbolPage = page
        rebuildKeys(for: page)
    }

    func setLetterCase(_ letterCase: KeyboardLetterCase) {
        guard self.letterCase != letterCase else { return }
        self.letterCase = letterCase
        guard symbolPage == .alphabetic else { return }

        let updatedModels = KeyboardSymbolLayout.rows(
            for: symbolPage,
            letterCase: letterCase
        ).flatMap { $0 }
        guard updatedModels.count == keyViews.count else {
            rebuildKeys(for: symbolPage)
            return
        }
        for (keyView, model) in zip(keyViews, updatedModels) {
            keyView.apply(
                model: model,
                state: keyView === activeKeyView ? .pressed : .normal,
                isTrackpadModeActive: spaceTrackpadController.isActive,
                animated: false
            )
        }
    }

    func setKeyboardEnabled(_ enabled: Bool) {
        guard isKeyboardEnabled != enabled else { return }
        isKeyboardEnabled = enabled
        updateKeyStates(activeKey: enabled ? activeKeyView : nil)
        if !enabled {
            cancelSpaceTrackpadIfNeeded()
            cancelDeleteRepeatIfNeeded()
            clearActiveKey(shouldDismissPopup: true)
        }
    }

    func setPopupContainerView(_ view: UIView?) {
        popupContainerView = view
    }

    func resetInteractionState() {
        touchRouter?.isEnabled = false
        touchRouter?.isEnabled = true
        cancelAllAlternatePresentations()
        alternatePopupView.dismiss()
        touchSessions.removeAll()
        recentlyCompletedRoutedTouches.removeAll()
        deleteTouchIdentifier = nil
        spaceTouchIdentifier = nil
        alternateTouchIdentifier = nil
        lastTouchBeganAt = nil
        lastTouchEndedAt = nil
        lastActivationAt = nil
        activeKeyView = nil
        trackpadOriginKeyView = nil
        isDeleteTouchConsuming = false
        _ = spaceTrackpadController.cancel()
        deleteRepeatController.cancel()
        popupView.dismiss()
        for keyView in keyViews {
            keyView.resetVisualState()
        }
    }

    func refreshAppearance() {
        updateKeyStates(activeKey: activeKeyView)
        popupView.refreshAppearance()
        alternatePopupView.setNeedsLayout()
    }

    func topRowKeyView(for slot: KeyboardTopRowAccessorySlot) -> UIView? {
        guard
            let firstRow = rowsStack.arrangedSubviews.first as? UIStackView,
            firstRow.arrangedSubviews.indices.contains(slot.rawValue)
        else {
            return nil
        }
        return firstRow.arrangedSubviews[slot.rawValue]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let isLandscape = window?.windowScene?.interfaceOrientation.isLandscape ?? false
        secondRowLayoutGeometry?.update(isLandscape: isLandscape)
        thirdRowLayoutGeometry?.update(isLandscape: isLandscape)
        bottomRowLayoutGeometry?.update(isLandscape: isLandscape)
        reportCharacterGeometryIfNeeded()
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        isMultipleTouchEnabled = true

        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.axis = .vertical
        rowsStack.alignment = .fill
        rowsStack.distribution = .fillEqually
        rowsStack.spacing = KeyboardStyle.keyboardRowSpacing
        rowsStack.clipsToBounds = false
        addSubview(rowsStack)

        let touchRouter = KeyboardTouchRouterGestureRecognizer(target: nil, action: nil)
        touchRouter.onTouchesBegan = { [weak self] touches, event in
            self?.routeTouchesBegan(touches, with: event, source: "gesture_router")
        }
        touchRouter.onTouchesMoved = { [weak self] touches, event in
            self?.routeTouchesMoved(touches, with: event)
        }
        touchRouter.onTouchesEnded = { [weak self] touches, _ in
            self?.finishRoutedTouches(touches, cancelled: false)
        }
        touchRouter.onTouchesCancelled = { [weak self] touches, _ in
            self?.finishRoutedTouches(touches, cancelled: true)
        }
        addGestureRecognizer(touchRouter)
        self.touchRouter = touchRouter

        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

    }

    private func rebuildKeys(for page: KeyboardSymbolPage) {
        cancelSpaceTrackpadIfNeeded()
        cancelDeleteRepeatIfNeeded()
        clearActiveKey(shouldDismissPopup: true)
        keyViews.removeAll()
        rowsStack.arrangedSubviews.forEach { row in
            rowsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        secondRowLayoutGeometry = nil
        thirdRowLayoutGeometry = nil
        bottomRowLayoutGeometry = nil

        for (rowIndex, rowModels) in KeyboardSymbolLayout.rows(
            for: page,
            letterCase: letterCase
        ).enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = rowIndex < 2 ? .fillEqually : .fillProportionally
            rowStack.spacing = KeyboardStyle.keySpacing
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            for model in rowModels {
                let keyView = KeyboardKeyView(model: model)
                keyViews.append(keyView)
                rowStack.addArrangedSubview(keyView)
            }

            rowsStack.addArrangedSubview(rowStack)

            if rowIndex == 1, page == .alphabetic {
                secondRowLayoutGeometry = KeyboardLayoutGeometry.SecondRowLayout(
                    keyGridView: self,
                    rowStack: rowStack
                )
            } else if rowIndex == 2 {
                thirdRowLayoutGeometry = KeyboardLayoutGeometry.ThirdRowLayout(
                    keyGridView: self,
                    rowStack: rowStack
                )
            } else if rowIndex == 3 {
                bottomRowLayoutGeometry = KeyboardLayoutGeometry.BottomRowLayout(
                    keyGridView: self,
                    rowStack: rowStack
                )
            }
        }

        updateKeyStates(activeKey: nil)
        setNeedsLayout()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(
            dx: -KeyboardStyle.keyGridHitOverflow,
            dy: -KeyboardStyle.keyGridHitOverflow
        ).contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled,
              !isHidden,
              alpha > 0.01,
              self.point(inside: point, with: event) else {
            return nil
        }
        return self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        routeTouchesBegan(touches, with: event, source: "responder_fallback")
    }

    private func routeTouchesBegan(
        _ touches: Set<UITouch>,
        with event: UIEvent?,
        source: String
    ) {
        guard isKeyboardEnabled else { return }

        for touch in touches {
            let handlingStartedAt = ProcessInfo.processInfo.systemUptime
            let identifier = ObjectIdentifier(touch)
            guard touchSessions[identifier] == nil else {
                continue
            }
            if let completedTouch = recentlyCompletedRoutedTouches[identifier] {
                if completedTouch.contains(timestamp: touch.timestamp) {
                    KeyboardTypingDiagnostics.log("touch_duplicate_suppressed", fields: [
                        "delivery_source": source,
                        "touch_timestamp": touch.timestamp,
                    ])
                    continue
                }
                recentlyCompletedRoutedTouches.removeValue(forKey: identifier)
            }
            let location = touch.location(in: self)
            let hitKey = keyView(at: location)
            let previousTouchBeganAt = lastTouchBeganAt
            let previousTouchEndedAt = lastTouchEndedAt
            let overlappingTouchCount = touchSessions.count
            let session = TouchSession(
                diagnosticIdentifier: KeyboardTypingDiagnostics.nextIdentifier(),
                beganAt: touch.timestamp,
                beganLocation: location,
                currentKeyView: hitKey
            )
            touchSessions[identifier] = session
            lastTouchBeganAt = touch.timestamp
            KeyboardTypingDiagnostics.log("touch_begin", fields: [
                "touch_id": session.diagnosticIdentifier,
                "x": diagnosticCoordinate(location.x),
                "y": diagnosticCoordinate(location.y),
                "resolved_key": diagnosticKeyName(hitKey?.model.kind),
                "inside_grid_bounds": bounds.contains(location),
                "active_touches": touchSessions.count,
                "overlapping_touches": overlappingTouchCount,
                "since_previous_touch_begin_ms": diagnosticOptionalDuration(
                    from: previousTouchBeganAt,
                    to: touch.timestamp
                ),
                "since_previous_touch_end_ms": diagnosticOptionalDuration(
                    from: previousTouchEndedAt,
                    to: touch.timestamp
                ),
                "key_offset_x": diagnosticKeyOffsetX(location, keyView: hitKey),
                "key_offset_y": diagnosticKeyOffsetY(location, keyView: hitKey),
                "delivery_delay_ms": diagnosticDuration(
                    from: touch.timestamp,
                    to: handlingStartedAt
                ),
                "delivery_source": source,
            ])

            if hitKey?.model.kind == .delete {
                guard deleteTouchIdentifier == nil else { continue }
                deleteTouchIdentifier = identifier
                isDeleteTouchConsuming = true
                setActiveKey(hitKey)
                deleteRepeatController.begin { [weak self] in
                    guard let self else { return true }
                    let didDelete = self.deliverKeyActivation(
                        KeyboardKeyActivation(
                            kind: .delete,
                            location: location,
                            timestamp: ProcessInfo.processInfo.systemUptime,
                            isLongPressAlternate: false
                        ),
                        session: session,
                        source: "delete_repeat"
                    )
                    if !didDelete {
                        self.deleteRepeatController.cancel()
                    }
                    return didDelete
                }
                continue
            }

            if hitKey?.model.kind == .space, spaceTouchIdentifier == nil {
                spaceTouchIdentifier = identifier
                trackpadOriginKeyView = hitKey
                trackpadActivationFeedback.prepare()
                spaceTrackpadController.begin(
                    onSpaceKey: true,
                    location: location
                ) { [weak self] in
                    self?.activateSpaceTrackpadIfNeeded()
                }
            }

            setActiveKey(hitKey)
            if popupView.superview != nil, popupView.alpha > 0 {
                let presentedAt = ProcessInfo.processInfo.systemUptime
                session.popupPresentedAt = presentedAt
                KeyboardTypingDiagnostics.log("popup_presented", fields: [
                    "touch_id": session.diagnosticIdentifier,
                    "key": diagnosticKeyName(hitKey?.model.kind),
                    "presentation_ms": diagnosticDuration(
                        from: handlingStartedAt,
                        to: presentedAt
                    ),
                    "x": diagnosticCoordinate(popupView.frame.origin.x),
                    "y": diagnosticCoordinate(popupView.frame.origin.y),
                    "width": diagnosticCoordinate(popupView.frame.width),
                    "height": diagnosticCoordinate(popupView.frame.height),
                ])
            }
            scheduleAlternatePresentation(for: hitKey, touchIdentifier: identifier)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        routeTouchesMoved(touches, with: event)
    }

    private func routeTouchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isKeyboardEnabled else { return }

        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            guard let session = touchSessions[identifier] else { continue }
            let location = touch.location(in: self)
            let timestamp = touch.timestamp
            guard timestamp > session.lastMovementTimestamp else { continue }
            session.lastMovementTimestamp = timestamp
            let rawHitKey = keyView(at: location)
            let hitKey = stabilizedKeyView(
                rawHitKey: rawHitKey,
                location: location,
                session: session
            )
            KeyboardTypingDiagnostics.log("touch_move", fields: [
                "touch_id": session.diagnosticIdentifier,
                "x": diagnosticCoordinate(location.x),
                "y": diagnosticCoordinate(location.y),
                "previous_key": diagnosticKeyName(session.currentKeyView?.model.kind),
                "resolved_key": diagnosticKeyName(hitKey?.model.kind),
                "raw_key": diagnosticKeyName(rawHitKey?.model.kind),
                "active_touches": touchSessions.count,
            ])

            if identifier == deleteTouchIdentifier {
                session.currentKeyView = rawHitKey
                if rawHitKey?.model.kind == .delete {
                    if rawHitKey !== activeKeyView {
                        setActiveKey(rawHitKey)
                    }
                    deleteRepeatController.resumeIfNeeded()
                } else {
                    clearActiveKey(shouldDismissPopup: true)
                    deleteRepeatController.pause()
                }
                continue
            }

            if identifier == spaceTouchIdentifier, spaceTrackpadController.isActive {
                let update = spaceTrackpadController.update(
                    location: location,
                    isStillOnSpaceKey: true
                )
                if let movementDelta = update.movementDelta {
                    onSpaceTrackpadEvent?(.moved(movementDelta, timestamp: timestamp))
                }
                continue
            }

            if identifier == alternateTouchIdentifier, alternatePopupView.superview != nil {
                alternatePopupView.updateSelection(
                    at: touch.location(in: popupContainerView ?? self),
                    in: popupContainerView ?? self
                )
                continue
            }

            if identifier == spaceTouchIdentifier {
                _ = spaceTrackpadController.update(
                    location: location,
                    isStillOnSpaceKey: rawHitKey?.model.kind == .space
                )
            }

            if hitKey !== session.currentKeyView {
                cancelAlternatePresentation(for: identifier)
                session.currentKeyView = hitKey
                setActiveKey(hitKey)
                scheduleAlternatePresentation(for: hitKey, touchIdentifier: identifier)
            } else if let hitKey {
                updatePopup(for: hitKey)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishResponderTouches(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishResponderTouches(touches, cancelled: true)
    }

    private func finishRoutedTouches(_ touches: Set<UITouch>, cancelled: Bool) {
        let completedTouchPairs: [(ObjectIdentifier, CompletedRoutedTouch)] = touches.compactMap {
            touch -> (ObjectIdentifier, CompletedRoutedTouch)? in
            let identifier = ObjectIdentifier(touch)
            guard let session = touchSessions[identifier] else { return nil }
            return (
                identifier,
                CompletedRoutedTouch(
                    beganAt: session.beganAt,
                    endedAt: touch.timestamp
                )
            )
        }
        let completedTouches = Dictionary(uniqueKeysWithValues: completedTouchPairs)
        let finishedIdentifiers = finishTouches(touches, cancelled: cancelled)
        for identifier in finishedIdentifiers {
            recentlyCompletedRoutedTouches[identifier] = completedTouches[identifier]
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.completedTouchRetentionDuration
        ) { [weak self] in
            guard let self else { return }
            for identifier in finishedIdentifiers
                where self.recentlyCompletedRoutedTouches[identifier]
                    == completedTouches[identifier] {
                self.recentlyCompletedRoutedTouches.removeValue(forKey: identifier)
            }
        }
    }

    private func finishResponderTouches(_ touches: Set<UITouch>, cancelled: Bool) {
        let unfinishedTouches = Set(touches.filter { touch in
            let identifier = ObjectIdentifier(touch)
            return recentlyCompletedRoutedTouches[identifier]?
                .contains(timestamp: touch.timestamp) != true
        })
        _ = finishTouches(unfinishedTouches, cancelled: cancelled)
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            if recentlyCompletedRoutedTouches[identifier]?
                .contains(timestamp: touch.timestamp) == true {
                recentlyCompletedRoutedTouches.removeValue(forKey: identifier)
            }
        }
    }

    @discardableResult
    private func finishTouches(
        _ touches: Set<UITouch>,
        cancelled: Bool
    ) -> Set<ObjectIdentifier> {
        var finishedIdentifiers = Set<ObjectIdentifier>()
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            guard let session = touchSessions.removeValue(forKey: identifier) else { continue }
            finishedIdentifiers.insert(identifier)
            let alternateValue = identifier == alternateTouchIdentifier
                ? alternatePopupView.selectedValue()
                : nil
            let location = touch.location(in: self)
            let rawHitKey = keyView(at: location)
            let hitKey = stabilizedKeyView(
                rawHitKey: rawHitKey,
                location: location,
                session: session
            )
            lastTouchEndedAt = touch.timestamp
            if let popupPresentedAt = session.popupPresentedAt {
                KeyboardTypingDiagnostics.log("popup_release_requested", fields: [
                    "touch_id": session.diagnosticIdentifier,
                    "key": diagnosticKeyName(session.currentKeyView?.model.kind),
                    "visible_before_release_ms": diagnosticDuration(
                        from: popupPresentedAt,
                        to: ProcessInfo.processInfo.systemUptime
                    ),
                ])
            }
            KeyboardTypingDiagnostics.log(cancelled ? "touch_cancel" : "touch_end", fields: [
                "touch_id": session.diagnosticIdentifier,
                "x": diagnosticCoordinate(location.x),
                "y": diagnosticCoordinate(location.y),
                "resolved_key": diagnosticKeyName(hitKey?.model.kind),
                "raw_key": diagnosticKeyName(rawHitKey?.model.kind),
                "last_key": diagnosticKeyName(session.currentKeyView?.model.kind),
                "initial_key": diagnosticKeyName(session.initialKeyView?.model.kind),
                "changed_key": hitKey !== session.initialKeyView,
                "travel_x": diagnosticCoordinate(location.x - session.beganLocation.x),
                "travel_y": diagnosticCoordinate(location.y - session.beganLocation.y),
                "initial_key_offset_x": diagnosticKeyOffsetX(
                    session.beganLocation,
                    keyView: session.initialKeyView
                ),
                "initial_key_offset_y": diagnosticKeyOffsetY(
                    session.beganLocation,
                    keyView: session.initialKeyView
                ),
                "duration_ms": diagnosticDuration(from: session.beganAt, to: touch.timestamp),
                "active_touches": touchSessions.count,
            ])
            cancelAlternatePresentation(for: identifier, session: session)

            if identifier == deleteTouchIdentifier {
                deleteTouchIdentifier = nil
                isDeleteTouchConsuming = false
                deleteRepeatController.cancel()
                refreshActiveKeyFromRemainingTouches()
                continue
            }

            let selectedKind: KeyboardKeyKind?
            if cancelled || !bounds.insetBy(dx: -16, dy: -16).contains(location) {
                selectedKind = nil
            } else {
                selectedKind = alternateValue.map(KeyboardKeyKind.character)
                    ?? hitKey?.model.kind
                    ?? session.currentKeyView?.model.kind
            }
            let isLongPressAlternate = alternateValue != nil
            if identifier == alternateTouchIdentifier {
                alternateTouchIdentifier = nil
                alternatePopupView.dismiss()
            }

            let wasTrackpadActive: Bool
            if identifier == spaceTouchIdentifier {
                spaceTouchIdentifier = nil
                wasTrackpadActive = cancelled
                    ? spaceTrackpadController.cancel()
                    : spaceTrackpadController.end()
                trackpadOriginKeyView = nil
            } else {
                wasTrackpadActive = false
            }

            refreshActiveKeyFromRemainingTouches()
            if wasTrackpadActive {
                onSpaceTrackpadEvent?(cancelled ? .cancelled : .ended)
                KeyboardTypingDiagnostics.log("trackpad_end", fields: [
                    "touch_id": session.diagnosticIdentifier,
                    "cancelled": cancelled,
                ])
            } else if let selectedKind, !cancelled {
                _ = deliverKeyActivation(
                    KeyboardKeyActivation(
                        kind: selectedKind,
                        location: location,
                        timestamp: touch.timestamp,
                        isLongPressAlternate: isLongPressAlternate
                    ),
                    session: session,
                    source: isLongPressAlternate ? "long_press_alternate" : "touch_end"
                )
            } else {
                KeyboardTypingDiagnostics.log("activation_skipped", fields: [
                    "touch_id": session.diagnosticIdentifier,
                    "cancelled": cancelled,
                    "inside_tolerance": bounds.insetBy(dx: -16, dy: -16).contains(location),
                    "resolved_key": diagnosticKeyName(selectedKind),
                ])
            }
        }
        return finishedIdentifiers
    }

    private func keyView(at point: CGPoint) -> KeyboardKeyView? {
        guard bounds.insetBy(
            dx: -KeyboardStyle.keyGridHitOverflow,
            dy: -KeyboardStyle.keyGridHitOverflow
        ).contains(point) else {
            return nil
        }

        return keyViews.min { left, right in
            squaredDistance(from: point, to: left.convert(left.bounds, to: self))
                < squaredDistance(from: point, to: right.convert(right.bounds, to: self))
        }
    }

    private func squaredDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let horizontalDistance = max(max(frame.minX - point.x, 0), point.x - frame.maxX)
        let verticalDistance = max(max(frame.minY - point.y, 0), point.y - frame.maxY)
        return horizontalDistance * horizontalDistance + verticalDistance * verticalDistance
    }

    private func stabilizedKeyView(
        rawHitKey: KeyboardKeyView?,
        location: CGPoint,
        session: TouchSession
    ) -> KeyboardKeyView? {
        guard let initialKeyView = session.initialKeyView else { return rawHitKey }
        guard rawHitKey !== initialKeyView else { return initialKeyView }

        if initialKeyView.model.kind == .space {
            return initialKeyView
        }

        guard case .character = initialKeyView.model.kind else { return rawHitKey }
        let horizontalMovement = location.x - session.beganLocation.x
        let verticalMovement = location.y - session.beganLocation.y
        let movementDistance = hypot(horizontalMovement, verticalMovement)
        guard movementDistance >= KeyboardStyle.keyHeight * 0.65,
              let rawHitKey else {
            return initialKeyView
        }
        let rawFrame = rawHitKey.convert(rawHitKey.bounds, to: self).insetBy(dx: 4, dy: 4)
        return rawFrame.contains(location) ? rawHitKey : initialKeyView
    }

    private func setActiveKey(_ keyView: KeyboardKeyView?) {
        activeKeyView = keyView
        updateKeyStates(activeKey: keyView)

        if let keyView, keyView.model.allowsPopup, let text = keyView.model.popupText {
            popupView.present(text: text, from: keyView, in: popupContainerView ?? self)
        } else {
            popupView.dismiss()
        }
    }

    private func updatePopup(for keyView: KeyboardKeyView) {
        guard keyView.model.allowsPopup, let text = keyView.model.popupText else {
            popupView.dismiss()
            return
        }
        popupView.present(text: text, from: keyView, in: popupContainerView ?? self)
    }

    private func clearActiveKey(shouldDismissPopup: Bool) {
        activeKeyView = nil
        updateKeyStates(activeKey: nil)
        if shouldDismissPopup {
            popupView.dismiss()
        }
    }

    private func scheduleAlternatePresentation(
        for keyView: KeyboardKeyView?,
        touchIdentifier: ObjectIdentifier
    ) {
        cancelAlternatePresentation(for: touchIdentifier)
        guard let session = touchSessions[touchIdentifier],
              let keyView,
              case let .character(value) = keyView.model.kind else {
            return
        }
        let alternates = KeyboardAlternateCharacterLayout.characters(for: value)
        guard alternates.isEmpty == false else { return }
        let workItem = DispatchWorkItem { [weak self, weak keyView, weak session] in
            guard let self,
                  let keyView,
                  let session,
                  self.touchSessions[touchIdentifier] === session,
                  session.currentKeyView === keyView else {
                return
            }
            if let existingIdentifier = self.alternateTouchIdentifier,
               existingIdentifier != touchIdentifier {
                self.cancelAlternatePresentation(for: existingIdentifier)
            }
            self.alternateTouchIdentifier = touchIdentifier
            self.popupView.dismiss()
            self.alternatePopupView.present(
                alternates: alternates,
                primaryValue: value,
                from: keyView,
                in: self.popupContainerView ?? self
            )
        }
        session.alternatePresentationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func cancelAlternatePresentation(
        for touchIdentifier: ObjectIdentifier,
        session suppliedSession: TouchSession? = nil
    ) {
        let session = suppliedSession ?? touchSessions[touchIdentifier]
        session?.alternatePresentationWorkItem?.cancel()
        session?.alternatePresentationWorkItem = nil
        if alternateTouchIdentifier == touchIdentifier {
            alternateTouchIdentifier = nil
            alternatePopupView.dismiss()
        }
    }

    private func cancelAllAlternatePresentations() {
        for (identifier, session) in touchSessions {
            cancelAlternatePresentation(for: identifier, session: session)
        }
    }

    private func refreshActiveKeyFromRemainingTouches() {
        let latestKeyView = touchSessions.values
            .filter { $0.currentKeyView != nil }
            .max { $0.beganAt < $1.beganAt }?
            .currentKeyView
        setActiveKey(latestKeyView)
    }

    private func deliverKeyActivation(
        _ activation: KeyboardKeyActivation,
        session: TouchSession,
        source: String
    ) -> Bool {
        let deliveryStartedAt = ProcessInfo.processInfo.systemUptime
        let previousActivationAt = lastActivationAt
        lastActivationAt = activation.timestamp
        KeyboardTypingDiagnostics.log("activation_begin", fields: [
            "touch_id": session.diagnosticIdentifier,
            "key": diagnosticKeyName(activation.kind),
            "source": source,
            "since_previous_activation_ms": diagnosticOptionalDuration(
                from: previousActivationAt,
                to: activation.timestamp
            ),
            "touch_to_activation_ms": diagnosticDuration(
                from: session.beganAt,
                to: deliveryStartedAt
            ),
        ])
        let wasHandled = KeyboardTypingDiagnostics.withTouchIdentifier(
            session.diagnosticIdentifier
        ) {
            onKeyActivated?(activation) ?? false
        }
        KeyboardTypingDiagnostics.log("activation_end", fields: [
            "touch_id": session.diagnosticIdentifier,
            "key": diagnosticKeyName(activation.kind),
            "handled": wasHandled,
            "handler_ms": diagnosticDuration(
                from: deliveryStartedAt,
                to: ProcessInfo.processInfo.systemUptime
            ),
        ])
        return wasHandled
    }

    private func diagnosticKeyName(_ kind: KeyboardKeyKind?) -> String {
        kind.map { String(describing: $0) } ?? "none"
    }

    private func diagnosticCoordinate(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    private func diagnosticDuration(from start: TimeInterval, to end: TimeInterval) -> Double {
        ((end - start) * 100_000).rounded() / 100
    }

    private func diagnosticOptionalDuration(
        from start: TimeInterval?,
        to end: TimeInterval
    ) -> Any {
        guard let start else { return NSNull() }
        return diagnosticDuration(from: start, to: end)
    }

    private func diagnosticKeyOffsetX(_ location: CGPoint, keyView: KeyboardKeyView?) -> Any {
        guard let keyView else { return NSNull() }
        let frame = keyView.convert(keyView.bounds, to: self)
        return diagnosticKeyOffset(location.x, minimum: frame.minX, maximum: frame.maxX)
    }

    private func diagnosticKeyOffsetY(_ location: CGPoint, keyView: KeyboardKeyView?) -> Any {
        guard let keyView else { return NSNull() }
        let frame = keyView.convert(keyView.bounds, to: self)
        return diagnosticKeyOffset(location.y, minimum: frame.minY, maximum: frame.maxY)
    }

    private func diagnosticKeyOffset(
        _ coordinate: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> Any {
        guard maximum > minimum else { return NSNull() }
        let midpoint = (minimum + maximum) / 2
        let halfLength = (maximum - minimum) / 2
        return diagnosticCoordinate((coordinate - midpoint) / halfLength)
    }

    private func reportCharacterGeometryIfNeeded() {
        guard symbolPage == .alphabetic, bounds.width > 0, bounds.height > 0 else { return }
        let geometry = keyViews.compactMap { keyView -> KeyboardCharacterKeyGeometry? in
            guard case let .character(value) = keyView.model.kind,
                  value.count == 1,
                  let character = value.lowercased().first else {
                return nil
            }
            return KeyboardCharacterKeyGeometry(
                character: character,
                frame: keyView.convert(keyView.bounds, to: self)
            )
        }
        guard geometry != lastReportedCharacterGeometry else { return }
        lastReportedCharacterGeometry = geometry
        onCharacterGeometryChange?(geometry, bounds.size)
    }

    private func updateKeyStates(activeKey: KeyboardKeyView?) {
        let isTrackpadModeActive = spaceTrackpadController.isActive
        for keyView in keyViews {
            let state: KeyboardKeyView.VisualState
            if !isKeyboardEnabled {
                state = .disabled
            } else if isTrackpadModeActive, keyView === trackpadOriginKeyView {
                state = .trackpadActive
            } else if keyView === activeKey {
                state = .pressed
            } else {
                state = .normal
            }
            keyView.apply(
                model: keyView.model,
                state: state,
                isTrackpadModeActive: isTrackpadModeActive
            )
        }
        alpha = 1.0
    }

    private func cancelSpaceTrackpadIfNeeded() {
        let wasTrackpadActive = spaceTrackpadController.cancel()
        trackpadOriginKeyView = nil
        if wasTrackpadActive {
            onSpaceTrackpadEvent?(.cancelled)
        }
    }

    private func cancelDeleteRepeatIfNeeded() {
        isDeleteTouchConsuming = false
        deleteRepeatController.cancel()
    }

    private func emitTrackpadActivationHaptic() {
        trackpadActivationFeedback.impactOccurred()
        trackpadActivationFeedback.prepare()
    }

    private func activateSpaceTrackpadIfNeeded() {
        guard trackpadOriginKeyView != nil else { return }
        emitTrackpadActivationHaptic()
        setActiveKey(trackpadOriginKeyView)
        popupView.dismiss()
        onSpaceTrackpadEvent?(.began)
    }
}
