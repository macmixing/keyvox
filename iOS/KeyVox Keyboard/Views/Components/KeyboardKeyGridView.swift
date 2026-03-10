import UIKit

final class KeyboardKeyGridView: UIView {
    var onKeyActivated: ((KeyboardKeyKind) -> Void)?
    var onSpaceTrackpadEvent: ((KeyboardSpaceTrackpadEvent) -> Void)?

    private let rowsStack = UIStackView()
    private let popupView = KeyboardKeyPopupView()
    private let pressGestureRecognizer = UILongPressGestureRecognizer()
    private var keyViews: [KeyboardKeyView] = []
    private(set) var symbolPage: KeyboardSymbolPage = .primary
    private var isKeyboardEnabled = true
    private weak var activeKeyView: KeyboardKeyView?
    private weak var popupContainerView: UIView?
    private weak var trackpadOriginKeyView: KeyboardKeyView?
    private let spaceTrackpadController = KeyboardSpaceTrackpadController()
    private let trackpadActivationFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var deleteRepeatController = KeyboardDeleteRepeatController()
    private var isDeleteTouchConsuming = false

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

    func setPopupContainerView(_ view: UIView) {
        popupContainerView = view
    }

    func resetInteractionState() {
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

    var topRowReferenceKeyView: UIView? {
        guard
            let firstRow = rowsStack.arrangedSubviews.first as? UIStackView,
            let trailingKeyView = firstRow.arrangedSubviews.last
        else {
            return nil
        }
        return trailingKeyView
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

        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor),
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

        for rowModels in KeyboardSymbolLayout.rows(for: page) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = .fillProportionally
            rowStack.spacing = KeyboardStyle.keySpacing
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            for model in rowModels {
                let keyView = KeyboardKeyView(model: model)
                keyViews.append(keyView)
                rowStack.addArrangedSubview(keyView)
            }

            rowsStack.addArrangedSubview(rowStack)
        }

        updateKeyStates(activeKey: nil)
    }

    @objc
    private func handlePressGesture(_ gesture: UILongPressGestureRecognizer) {
        guard isKeyboardEnabled else { return }

        let location = gesture.location(in: self)
        let hitKey = keyView(at: location)
        switch gesture.state {
        case .began:
            if hitKey?.model.kind == .delete {
                isDeleteTouchConsuming = true
                trackpadOriginKeyView = nil
                _ = spaceTrackpadController.cancel()
                setActiveKey(hitKey)
                deleteRepeatController.begin { [weak self] in
                    self?.onKeyActivated?(.delete)
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
                    onSpaceTrackpadEvent?(.moved(movementDelta))
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
            if isDeleteTouchConsuming {
                isDeleteTouchConsuming = false
                deleteRepeatController.cancel()
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
                onKeyActivated?(selectedKind)
            }
        case .cancelled, .failed:
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

    private func keyView(at point: CGPoint) -> KeyboardKeyView? {
        keyViews.first { keyView in
            let frame = keyView.convert(keyView.bounds, to: self).insetBy(dx: -6, dy: -6)
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
