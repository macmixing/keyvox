import UIKit

enum KeyboardTopRowAccessorySlot: Int, CaseIterable {
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
    var onKeyActivated: ((KeyboardKeyKind) -> Bool)?
    var onCompactKeysRequested: (() -> Bool)?
    var onSpaceTrackpadEvent: ((KeyboardSpaceTrackpadEvent) -> Void)?

    private let rowsStack = UIStackView()
    private let topRowAccessoryReferenceStack = UIStackView()
    private var topRowAccessoryReferenceViews: [UIView] = []
    private let popupView = KeyboardKeyPopupView()
    private let pressGestureRecognizer = UILongPressGestureRecognizer()
    private var keyViews: [KeyboardKeyView] = []
    private(set) var symbolPage: KeyboardSymbolPage = .primary
    private(set) var keysMode: KeyboardKeysMode = .full
    private var isKeyboardEnabled = true
    private weak var activeKeyView: KeyboardKeyView?
    private weak var popupContainerView: UIView?
    private weak var trackpadOriginKeyView: KeyboardKeyView?
    private let spaceTrackpadController = KeyboardSpaceTrackpadController()
    private let compactKeysHoldController = KeyboardCompactKeysHoldController()
    private let trackpadActivationFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var deleteRepeatController = KeyboardDeleteRepeatController()
    private var isDeleteTouchConsuming = false
    private var thirdRowLayoutGeometry: KeyboardLayoutGeometry.ThirdRowLayout?
    private var bottomRowLayoutGeometry: KeyboardLayoutGeometry.BottomRowLayout?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        rebuildKeys(for: symbolPage)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLayout(symbolPage page: KeyboardSymbolPage, keysMode: KeyboardKeysMode) {
        guard page != symbolPage || keysMode != self.keysMode else { return }
        symbolPage = page
        self.keysMode = keysMode
        rebuildKeys(for: page)
    }

    func setKeyboardEnabled(_ enabled: Bool) {
        guard isKeyboardEnabled != enabled else { return }
        isKeyboardEnabled = enabled
        updateKeyStates(activeKey: enabled ? activeKeyView : nil)
        if !enabled {
            compactKeysHoldController.cancel()
            cancelSpaceTrackpadIfNeeded()
            cancelDeleteRepeatIfNeeded()
            clearActiveKey(shouldDismissPopup: true)
        }
    }

    func setPopupContainerView(_ view: UIView?) {
        popupContainerView = view
    }

    func resetInteractionState() {
        activeKeyView = nil
        trackpadOriginKeyView = nil
        isDeleteTouchConsuming = false
        _ = spaceTrackpadController.cancel()
        compactKeysHoldController.cancel()
        deleteRepeatController.cancel()
        popupView.dismiss()
        for keyView in keyViews {
            keyView.resetVisualState()
        }
    }

    func refreshAppearance() {
        updateKeyStates(activeKey: activeKeyView)
        popupView.refreshAppearance()
    }

    func topRowKeyView(for slot: KeyboardTopRowAccessorySlot) -> UIView? {
        guard topRowAccessoryReferenceViews.indices.contains(slot.rawValue) else {
            return nil
        }
        return topRowAccessoryReferenceViews[slot.rawValue]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let isLandscape = window?.windowScene?.interfaceOrientation.isLandscape ?? false
        thirdRowLayoutGeometry?.update(isLandscape: isLandscape)
        bottomRowLayoutGeometry?.update(isLandscape: isLandscape)
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false

        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.axis = .vertical
        rowsStack.alignment = .fill
        rowsStack.distribution = .fillEqually
        rowsStack.spacing = KeyboardStyle.keyboardRowSpacing
        rowsStack.clipsToBounds = false
        addSubview(rowsStack)

        topRowAccessoryReferenceStack.translatesAutoresizingMaskIntoConstraints = false
        topRowAccessoryReferenceStack.axis = .horizontal
        topRowAccessoryReferenceStack.alignment = .fill
        topRowAccessoryReferenceStack.distribution = .fillEqually
        topRowAccessoryReferenceStack.spacing = KeyboardStyle.keySpacing
        topRowAccessoryReferenceStack.alpha = 0
        topRowAccessoryReferenceStack.isUserInteractionEnabled = false
        addSubview(topRowAccessoryReferenceStack)

        topRowAccessoryReferenceViews = KeyboardTopRowAccessorySlot.allCases.map { _ in
            let referenceView = UIView()
            referenceView.translatesAutoresizingMaskIntoConstraints = false
            topRowAccessoryReferenceStack.addArrangedSubview(referenceView)
            return referenceView
        }

        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            topRowAccessoryReferenceStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            topRowAccessoryReferenceStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            topRowAccessoryReferenceStack.topAnchor.constraint(equalTo: topAnchor),
            topRowAccessoryReferenceStack.heightAnchor.constraint(equalToConstant: KeyboardStyle.keyHeight),
        ])

        pressGestureRecognizer.minimumPressDuration = 0
        pressGestureRecognizer.cancelsTouchesInView = true
        pressGestureRecognizer.delaysTouchesBegan = false
        pressGestureRecognizer.addTarget(self, action: #selector(handlePressGesture(_:)))
        addGestureRecognizer(pressGestureRecognizer)
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
        thirdRowLayoutGeometry = nil
        bottomRowLayoutGeometry = nil

        for rowModels in KeyboardSymbolLayout.rows(for: page, keysMode: keysMode) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = rowModels.allSatisfy { $0.widthUnits == 1 }
                ? .fillEqually
                : .fillProportionally
            rowStack.spacing = KeyboardStyle.keySpacing
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            for model in rowModels {
                let keyView = KeyboardKeyView(model: model)
                keyViews.append(keyView)
                rowStack.addArrangedSubview(keyView)
            }

            rowsStack.addArrangedSubview(rowStack)

            if rowModels.contains(where: { $0.kind == .delete }) {
                thirdRowLayoutGeometry = KeyboardLayoutGeometry.ThirdRowLayout(
                    keyGridView: self,
                    rowStack: rowStack
                )
            } else if rowModels.contains(where: { $0.kind == .space }) {
                bottomRowLayoutGeometry = KeyboardLayoutGeometry.BottomRowLayout(
                    keyGridView: self,
                    rowStack: rowStack
                )
            }
        }

        updateKeyStates(activeKey: nil)
    }

    @objc
    private func handlePressGesture(_ gesture: UILongPressGestureRecognizer) {
        guard isKeyboardEnabled else { return }

        let location = gesture.location(in: self)
        let timestamp = ProcessInfo.processInfo.systemUptime
        let hitKey = keyView(at: location)
        switch gesture.state {
        case .began:
            compactKeysHoldController.begin(
                onCompactKeysTrigger: hitKey?.model.kind == .alternateSymbols,
                onActivate: { [weak self] in
                    self?.onCompactKeysRequested?() ?? false
                }
            )
            if hitKey?.model.kind == .delete {
                isDeleteTouchConsuming = true
                trackpadOriginKeyView = nil
                _ = spaceTrackpadController.cancel()
                setActiveKey(hitKey)
                deleteRepeatController.begin { [weak self] in
                    guard let self else { return true }
                    let didDelete = self.onKeyActivated?(.delete) ?? false
                    if !didDelete {
                        self.deleteRepeatController.cancel()
                    }
                    return didDelete
                }
                return
            }

            isDeleteTouchConsuming = false
            trackpadOriginKeyView = hitKey?.model.kind == .space ? hitKey : nil
            if trackpadOriginKeyView != nil {
                trackpadActivationFeedback.prepare()
            }
            spaceTrackpadController.begin(
                onSpaceKey: hitKey?.model.kind == .space,
                location: location
            ) { [weak self] in
                self?.activateSpaceTrackpadIfNeeded()
            }
            if hitKey !== activeKeyView {
                setActiveKey(hitKey)
            } else if let hitKey {
                updatePopup(for: hitKey)
            }
        case .changed:
            compactKeysHoldController.update(
                isStillOnCompactKeysTrigger: keyView(
                    at: location,
                    hitSlop: 0
                )?.model.kind == .alternateSymbols
            )
            if isDeleteTouchConsuming {
                if hitKey?.model.kind == .delete {
                    if hitKey !== activeKeyView {
                        setActiveKey(hitKey)
                    }
                    deleteRepeatController.resumeIfNeeded()
                } else {
                    clearActiveKey(shouldDismissPopup: true)
                    deleteRepeatController.pause()
                }
                return
            }

            if spaceTrackpadController.isActive {
                let update = spaceTrackpadController.update(
                    location: location,
                    isStillOnSpaceKey: true
                )
                if let movementDelta = update.movementDelta {
                    onSpaceTrackpadEvent?(.moved(movementDelta, timestamp: timestamp))
                }
                return
            }

            _ = spaceTrackpadController.update(
                location: location,
                isStillOnSpaceKey: hitKey?.model.kind == .space
            )

            if hitKey !== activeKeyView {
                setActiveKey(hitKey)
            } else if let hitKey {
                updatePopup(for: hitKey)
            }
        case .ended:
            let didActivateCompactKeys = compactKeysHoldController.end()
            if isDeleteTouchConsuming {
                isDeleteTouchConsuming = false
                deleteRepeatController.cancel()
                clearActiveKey(shouldDismissPopup: true)
                return
            }

            if didActivateCompactKeys {
                trackpadOriginKeyView = nil
                _ = spaceTrackpadController.cancel()
                clearActiveKey(shouldDismissPopup: true)
                return
            }

            let wasTrackpadActive = spaceTrackpadController.end()
            let selectedKind = hitKey?.model.kind ?? activeKeyView?.model.kind
            trackpadOriginKeyView = nil
            clearActiveKey(shouldDismissPopup: true)
            if wasTrackpadActive {
                onSpaceTrackpadEvent?(.ended)
            } else if let selectedKind {
                _ = onKeyActivated?(selectedKind)
            }
        case .cancelled, .failed:
            compactKeysHoldController.cancel()
            if isDeleteTouchConsuming {
                isDeleteTouchConsuming = false
                deleteRepeatController.cancel()
                clearActiveKey(shouldDismissPopup: true)
                return
            }

            let wasTrackpadActive = spaceTrackpadController.cancel()
            trackpadOriginKeyView = nil
            clearActiveKey(shouldDismissPopup: true)
            if wasTrackpadActive {
                onSpaceTrackpadEvent?(.cancelled)
            }
        default:
            break
        }
    }

    private func keyView(at point: CGPoint, hitSlop: CGFloat = 6) -> KeyboardKeyView? {
        keyViews.first { keyView in
            let frame = keyView.convert(keyView.bounds, to: self)
                .insetBy(dx: -hitSlop, dy: -hitSlop)
            return frame.contains(point)
        }
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
