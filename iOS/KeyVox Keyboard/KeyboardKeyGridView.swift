import UIKit

final class KeyboardKeyGridView: UIView {
    var onKeyActivated: ((KeyboardKeyKind) -> Void)?

    private let rowsStack = UIStackView()
    private let popupView = KeyboardKeyPopupView()
    private let pressGestureRecognizer = UILongPressGestureRecognizer()
    private var keyViews: [KeyboardKeyView] = []
    private(set) var symbolPage: KeyboardSymbolPage = .primary
    private var isKeyboardEnabled = true
    private weak var activeKeyView: KeyboardKeyView?
    private weak var popupContainerView: UIView?

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
            clearActiveKey(shouldDismissPopup: true)
        }
    }

    func setPopupContainerView(_ view: UIView) {
        popupContainerView = view
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
        case .began, .changed:
            if hitKey !== activeKeyView {
                setActiveKey(hitKey)
            } else if let hitKey {
                updatePopup(for: hitKey)
            }
        case .ended:
            let selectedKind = hitKey?.model.kind ?? activeKeyView?.model.kind
            clearActiveKey(shouldDismissPopup: true)
            if let selectedKind {
                onKeyActivated?(selectedKind)
            }
        case .cancelled, .failed:
            clearActiveKey(shouldDismissPopup: true)
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
        for keyView in keyViews {
            let state: KeyboardKeyView.VisualState
            if !isKeyboardEnabled {
                state = .disabled
            } else if keyView === activeKey {
                state = .pressed
            } else {
                state = .normal
            }
            keyView.apply(model: keyView.model, state: state)
        }
        alpha = 1.0
    }
}
