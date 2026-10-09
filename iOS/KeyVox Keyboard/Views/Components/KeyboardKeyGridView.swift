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
    var onKeyActivated: ((KeyboardKeyActivation) -> Bool)?
    /// Deletes whole words for a held delete key; false when none could be, so a character is
    /// deleted instead.
    var onDeleteWords: ((Int) -> Bool)?
    /// Called the moment a finger lands on a character key, before it types.
    var onCharacterKeyTouchDown: (() -> Void)?
    /// Called the moment a finger lands on any key, with the press it would make now.
    var onKeyTouchDown: ((KeyboardKeyActivation) -> Void)?
    var onCompactKeysRequested: (() -> Bool)?
    var onSpaceTrackpadEvent: ((KeyboardSpaceTrackpadEvent) -> Void)?
    /// Letter key frames whenever the letter page lays out differently.
    var onCharacterGeometryChange: (([KeyboardCharacterKeyGeometry], CGSize) -> Void)?

    private let rowsStack = UIStackView()
    private let topRowAccessoryReferenceStack = UIStackView()
    private var topRowAccessoryReferenceViews: [UIView] = []
    private var topRowAccessoryReferenceHeightConstraint: NSLayoutConstraint?
    let popupView = KeyboardKeyPopupView()
    let touchRouter = KeyboardTouchRouterGestureRecognizer()
    private(set) var keyViews: [KeyboardKeyView] = []
    private var baseModels: [ObjectIdentifier: KeyboardKeyModel] = [:]
    private(set) var symbolPage: KeyboardSymbolPage = .letters
    private(set) var keysMode: KeyboardKeysMode = .full
    private(set) var showsNextKeyboardKey = false
    private(set) var letterCase: KeyboardLetterCase = .lowercase
    private(set) var isKeyboardEnabled = true
    weak var popupContainerView: UIView?
    weak var popupOwnerKeyView: KeyboardKeyView?
    weak var trackpadOriginKeyView: KeyboardKeyView?
    var touchSessions: [ObjectIdentifier: KeyboardKeyTouchSession] = [:]
    let spaceTrackpadController = KeyboardSpaceTrackpadController()
    let compactKeysHoldController = KeyboardCompactKeysHoldController()
    let trackpadActivationFeedback = UIImpactFeedbackGenerator(style: .medium)
    let deleteRepeatController = KeyboardDeleteRepeatController()
    private var letterSecondRowLayoutGeometry: KeyboardLayoutGeometry.LetterSecondRowLayout?
    private var letterThirdRowLayoutGeometry: KeyboardLayoutGeometry.LetterThirdRowLayout?
    private var thirdRowLayoutGeometry: KeyboardLayoutGeometry.ThirdRowLayout?
    private var bottomRowLayoutGeometry: KeyboardLayoutGeometry.BottomRowLayout?
    private var lastReportedCharacterGeometry: [KeyboardCharacterKeyGeometry] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        rebuildKeys()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLayout(
        symbolPage page: KeyboardSymbolPage,
        keysMode: KeyboardKeysMode,
        showsNextKeyboardKey: Bool
    ) {
        guard page != symbolPage
                || keysMode != self.keysMode
                || showsNextKeyboardKey != self.showsNextKeyboardKey else { return }
        symbolPage = page
        self.keysMode = keysMode
        self.showsNextKeyboardKey = showsNextKeyboardKey
        rebuildKeys()
    }

    func setLetterCase(_ letterCase: KeyboardLetterCase) {
        guard letterCase != self.letterCase else { return }
        self.letterCase = letterCase
        for keyView in keyViews {
            guard let baseModel = baseModels[ObjectIdentifier(keyView)] else { continue }
            let casedModel = baseModel.applying(letterCase)
            guard casedModel != keyView.model else { continue }
            keyView.apply(
                model: casedModel,
                state: keyView.visualState,
                isTrackpadModeActive: spaceTrackpadController.isActive,
                animated: false
            )
        }
    }

    func setKeyboardEnabled(_ enabled: Bool) {
        guard isKeyboardEnabled != enabled else { return }
        isKeyboardEnabled = enabled
        if !enabled {
            cancelAllTouches()
        }
        updateAllKeyStates()
    }

    func setPopupContainerView(_ view: UIView?) {
        popupContainerView = view
    }

    func resetInteractionState() {
        touchSessions.removeAll()
        trackpadOriginKeyView = nil
        popupOwnerKeyView = nil
        _ = spaceTrackpadController.cancel()
        compactKeysHoldController.cancel()
        deleteRepeatController.cancel()
        popupView.dismiss()
        for keyView in keyViews {
            keyView.resetVisualState()
        }
    }

    func refreshAppearance() {
        updateAllKeyStates()
        popupView.refreshAppearance()
    }

    /// Matches the top-row reference views to the keys' height, which the landscape toolbar
    /// buttons take as their own.
    func setTopRowKeyHeight(_ height: CGFloat) {
        guard let topRowAccessoryReferenceHeightConstraint,
              topRowAccessoryReferenceHeightConstraint.constant != height else { return }
        topRowAccessoryReferenceHeightConstraint.constant = height
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
        letterSecondRowLayoutGeometry?.update(isLandscape: isLandscape)
        letterThirdRowLayoutGeometry?.update(isLandscape: isLandscape)
        thirdRowLayoutGeometry?.update(isLandscape: isLandscape)
        bottomRowLayoutGeometry?.update(isLandscape: isLandscape)
        reportCharacterGeometryIfNeeded()
    }

    /// How far outside its bounds the grid still takes touches: the gap up to the toolbar
    /// and the keyboard's side and bottom padding, so a tap just past the outer keys types
    /// the nearest key instead of landing on nothing.
    static let touchOverflow = UIEdgeInsets(
        top: KeyboardStyle.sectionSpacing,
        left: KeyboardStyle.horizontalPadding,
        bottom: KeyboardStyle.bottomPadding,
        right: KeyboardStyle.horizontalPadding
    )

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(
            top: -Self.touchOverflow.top,
            left: -Self.touchOverflow.left,
            bottom: -Self.touchOverflow.bottom,
            right: -Self.touchOverflow.right
        )).contains(point)
    }

    /// The key a touch belongs to: the key containing it, or else the nearest key within
    /// `hitSlop`, so touches in the gaps between and around keys still land.
    func keyView(at point: CGPoint, hitSlop: CGFloat = KeyboardStyle.sectionSpacing) -> KeyboardKeyView? {
        var nearest: (keyView: KeyboardKeyView, distance: CGFloat)?
        for keyView in keyViews {
            let frame = keyView.convert(keyView.bounds, to: self)
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            let distance = (dx * dx + dy * dy).squareRoot()
            guard distance <= hitSlop else { continue }
            if distance == 0 { return keyView }
            if nearest == nil || distance < nearest!.distance {
                nearest = (keyView, distance)
            }
        }
        return nearest?.keyView
    }

    func setVisualState(_ state: KeyboardKeyView.VisualState, for keyView: KeyboardKeyView) {
        let resolvedState: KeyboardKeyView.VisualState = isKeyboardEnabled ? state : .disabled
        guard keyView.visualState != resolvedState else { return }
        keyView.apply(
            model: keyView.model,
            state: resolvedState,
            isTrackpadModeActive: spaceTrackpadController.isActive
        )
    }

    func updateAllKeyStates() {
        let isTrackpadModeActive = spaceTrackpadController.isActive
        let pressedKeys = Set(touchSessions.values.compactMap { $0.keyView.map(ObjectIdentifier.init) })
        for keyView in keyViews {
            let state: KeyboardKeyView.VisualState
            if !isKeyboardEnabled {
                state = .disabled
            } else if isTrackpadModeActive, keyView === trackpadOriginKeyView {
                state = .trackpadActive
            } else if pressedKeys.contains(ObjectIdentifier(keyView)) {
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

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        isMultipleTouchEnabled = true
        backgroundColor = KeyboardStyle.touchableClearColor

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

        let referenceHeightConstraint = topRowAccessoryReferenceStack.heightAnchor.constraint(
            equalToConstant: KeyboardStyle.keyHeight
        )
        topRowAccessoryReferenceHeightConstraint = referenceHeightConstraint

        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            topRowAccessoryReferenceStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            topRowAccessoryReferenceStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            topRowAccessoryReferenceStack.topAnchor.constraint(equalTo: topAnchor),
            referenceHeightConstraint,
        ])

        configureTouchRouter()
    }

    private func rebuildKeys() {
        cancelAllTouches()
        keyViews.removeAll()
        baseModels.removeAll()
        rowsStack.arrangedSubviews.forEach { row in
            rowsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        letterSecondRowLayoutGeometry = nil
        letterThirdRowLayoutGeometry = nil
        thirdRowLayoutGeometry = nil
        bottomRowLayoutGeometry = nil
        lastReportedCharacterGeometry = []

        let rows = KeyboardSymbolLayout.rows(
            for: symbolPage,
            keysMode: keysMode,
            showsNextKeyboardKey: showsNextKeyboardKey
        )
        for (rowIndex, rowModels) in rows.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = rowModels.allSatisfy { $0.widthUnits == 1 }
                ? .fillEqually
                : .fillProportionally
            rowStack.spacing = KeyboardStyle.keySpacing
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            for model in rowModels {
                let keyView = KeyboardKeyView(model: model.applying(letterCase))
                keyViews.append(keyView)
                baseModels[ObjectIdentifier(keyView)] = model
                rowStack.addArrangedSubview(keyView)
            }

            rowsStack.addArrangedSubview(rowStack)

            if symbolPage == .letters, keysMode == .full, rowIndex == 1 {
                letterSecondRowLayoutGeometry = KeyboardLayoutGeometry.LetterSecondRowLayout(
                    keyGridView: self,
                    rowStack: rowStack
                )
            } else if rowModels.contains(where: { $0.kind == .delete }) {
                if symbolPage == .letters {
                    letterThirdRowLayoutGeometry = KeyboardLayoutGeometry.LetterThirdRowLayout(
                        keyGridView: self,
                        rowStack: rowStack
                    )
                } else {
                    thirdRowLayoutGeometry = KeyboardLayoutGeometry.ThirdRowLayout(
                        keyGridView: self,
                        rowStack: rowStack
                    )
                }
            } else if rowModels.contains(where: { $0.kind == .space }) {
                bottomRowLayoutGeometry = KeyboardLayoutGeometry.BottomRowLayout(
                    keyGridView: self,
                    rowStack: rowStack
                )
            }
        }

        updateAllKeyStates()
        setNeedsLayout()
    }

    private func reportCharacterGeometryIfNeeded() {
        guard symbolPage == .letters else { return }
        // Rows and their keys lay out after this view, so settle both first or the frames
        // read below are from the previous layout pass.
        rowsStack.layoutIfNeeded()
        rowsStack.arrangedSubviews.forEach { $0.layoutIfNeeded() }
        let geometry = keyViews.compactMap { keyView -> KeyboardCharacterKeyGeometry? in
            guard case let .character(value) = keyView.model.kind,
                  value.count == 1,
                  let character = value.lowercased().first,
                  character.isLetter else {
                return nil
            }
            return KeyboardCharacterKeyGeometry(
                character: character,
                frame: keyView.convert(keyView.bounds, to: self)
            )
        }
        guard geometry.isEmpty == false,
              geometry.allSatisfy({ $0.frame.width > 0 && $0.frame.height > 0 }),
              geometry != lastReportedCharacterGeometry else { return }
        lastReportedCharacterGeometry = geometry
        onCharacterGeometryChange?(geometry, bounds.size)
    }
}
