import KeyVoxPredictiveKeyboard
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
    /// Called the moment a character key types, as its finger lifts or another finger lands.
    var onCharacterKeyTyped: (() -> Void)?
    /// Called the moment a held key's popup opens.
    var onHeldKeyPopupOpened: (() -> Void)?
    /// Called the moment the finger lifts off the delete key.
    var onDeleteKeyUp: (() -> Void)?
    /// Called the moment a finger lands on any key, with the press it would make now.
    var onKeyTouchDown: ((KeyboardKeyActivation) -> Void)?
    /// Called with the view the globe's finger landed in and the event of each of its touches, as it
    /// lands, moves, and lifts, for the system to move on to the next keyboard or list them.
    var onNextKeyboardTouch: ((UIView, UIEvent) -> Void)?
    var onCompactKeysRequested: (() -> Bool)?
    var onSpaceTrackpadEvent: ((KeyboardSpaceTrackpadEvent) -> Void)?
    /// Called with one place forward or back when a finger slid sideways across the space bar
    /// (`KeyboardSpaceLanguageSlide`), in place of typing a space.
    var onSpaceLanguageSlide: ((Int) -> Void)?
    /// Letter key frames whenever the letter page lays out differently.
    var onCharacterGeometryChange: (([KeyboardCharacterKeyGeometry], CGSize) -> Void)?
    /// Called with a swipe's path, in this view's coordinates, the moment its finger lifts or
    /// another finger lands, and, for a finger held undecided, where its word would have gone when
    /// it lifted (`swipePlace`).
    var onSwipeEnded: (([SwipeTouchSample], KeyboardSwipePlace?) -> Void)?
    /// Where a swiped word would go now, read when a finger lifts undecided.
    var swipePlace: (() -> KeyboardSwipePlace?)?
    /// Whether a finger sliding across the letter keys may swipe a word; while false, the swipe
    /// gate never runs and every touch is a key press.
    var allowsSwipeTyping = false {
        didSet {
            guard allowsSwipeTyping != oldValue, allowsSwipeTyping == false else { return }
            cancelSwipeTracking()
        }
    }
    /// Decides which fingers on the letter keys are swiping (`SwipeGate`).
    var swipeGate = SwipeGate<ObjectIdentifier>()
    /// Fingers that lifted right after meeting the swipe threshold at speed: taps when another
    /// finger lands soon, swipes otherwise.
    var undecidedSwipeSessions: [ObjectIdentifier: KeyboardKeyTouchSession] = [:]
    /// The distance between neighboring letter key centers across a row, in points.
    private(set) var letterKeyPitch: CGFloat = 0
    let swipeTrailView = KeyboardSwipeTrailView()

    /// Every page shown so far, kept so showing it again does not build it again.
    private var pages: [KeyboardKeyGridPage.Layout: KeyboardKeyGridPage] = [:]
    private var currentPage: KeyboardKeyGridPage?
    /// The key flip that shows a change of typing language, while it plays.
    private let keyFlipTransition = KeyboardKeyFlipTransition()
    private var rowSpacing = KeyboardStyle.keyboardRowSpacing
    private var displayZoomScale: CGFloat = 1
    private let topRowAccessoryReferenceStack = UIStackView()
    private var topRowAccessoryReferenceViews: [UIView] = []
    private var topRowAccessoryReferenceHeightConstraint: NSLayoutConstraint?
    let popupView = KeyboardKeyPopupView()
    let heldKeyPopupView = KeyboardHeldKeyPopupView()
    let touchRouter = KeyboardTouchRouterGestureRecognizer()
    /// The keys of the page showing.
    var keyViews: [KeyboardKeyView] { currentPage?.keyViews ?? [] }
    private(set) var symbolPage: KeyboardSymbolPage = .letters
    private(set) var keysMode: KeyboardKeysMode = .full
    /// Whether the keys type into the emoji search, which shows its own bottom row.
    private(set) var isEmojiSearch = false
    /// Whether the bottom row has the emoji key, unless the user turned emoji off.
    private(set) var showsEmojiKey = true
    /// Whether the bottom row has the globe, where the system shows none under the keyboard.
    private(set) var showsNextKeyboardKey = false
    /// The keys the focused field asks for.
    private(set) var fieldKeys = KeyboardFieldKeys.standard
    /// Whether the return key takes taps; a field that turns it on only once it holds text greys it
    /// out while empty.
    private(set) var isReturnKeyEnabled = true
    /// Whether holding the space bar turns the keyboard into a trackpad for the cursor; the emoji
    /// search has no cursor to move.
    var allowsSpaceTrackpad = true
    /// Whether sliding across the space bar switches the typing language, as while the keyboard has
    /// more than one; never in the emoji search, whose space bar types into the search.
    var allowsSpaceLanguageSlide = false
    private(set) var letterCase: KeyboardLetterCase = .lowercase
    private(set) var accentKeyLabel: KeyboardAccentKeyLabel?
    private(set) var isKeyboardEnabled = true
    weak var popupContainerView: UIView?
    weak var popupOwnerKeyView: KeyboardKeyView?
    weak var trackpadOriginKeyView: KeyboardKeyView?
    var touchSessions: [ObjectIdentifier: KeyboardKeyTouchSession] = [:]
    let spaceTrackpadController = KeyboardSpaceTrackpadController()
    let compactKeysHoldController = KeyboardCompactKeysHoldController()
    let heldKeyController = KeyboardHeldKeyController()
    /// The finger on a key that offers characters when held, while its popup is coming or open.
    weak var heldKeyTouchSession: KeyboardKeyTouchSession?
    let trackpadActivationFeedback = UIImpactFeedbackGenerator(style: .medium)
    let deleteRepeatController = KeyboardDeleteRepeatController()
    private var lastReportedCharacterGeometry: [KeyboardCharacterKeyGeometry] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        showPage()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLayout(
        symbolPage page: KeyboardSymbolPage,
        keysMode: KeyboardKeysMode,
        isEmojiSearch: Bool,
        showsEmojiKey: Bool,
        showsNextKeyboardKey: Bool,
        fieldKeys: KeyboardFieldKeys
    ) {
        guard page != symbolPage || keysMode != self.keysMode || isEmojiSearch != self.isEmojiSearch
            || showsEmojiKey != self.showsEmojiKey || showsNextKeyboardKey != self.showsNextKeyboardKey
            || fieldKeys != self.fieldKeys else { return }
        symbolPage = page
        self.keysMode = keysMode
        self.isEmojiSearch = isEmojiSearch
        self.showsEmojiKey = showsEmojiKey
        self.showsNextKeyboardKey = showsNextKeyboardKey
        self.fieldKeys = fieldKeys
        showPage()
    }

    /// The short code of the language the keyboard types in and its full name, shown on the space
    /// bar of every page that shows, or nil to show none.
    var languageCode: (code: String, name: String)? {
        didSet { showLanguageCode() }
    }

    private func showLanguageCode() {
        keyViews.first { $0.model.kind == .space }?.showLanguageCode(languageCode?.code, name: languageCode?.name)
    }

    /// Shows the letter keys in the layout the keyboard types in now, building its page the first
    /// time, and reports the letter key frames again, since a new language's suggestions start
    /// without them even when its layout is the same. The keys showing turn over into the new
    /// ones in a wave going `flipDirection` (`KeyboardKeyFlipTransition`); the new keys take
    /// touches from the start.
    func showCurrentLetterLayout(flipDirection: KeyboardKeyFlipWave.Direction) {
        lastReportedCharacterGeometry = []
        let outgoingPage = currentPage
        showPage()
        guard let outgoingPage else { return }
        flipKeys(from: outgoingPage, direction: flipDirection)
    }

    func setReturnKeyEnabled(_ enabled: Bool) {
        guard enabled != isReturnKeyEnabled else { return }
        isReturnKeyEnabled = enabled
        updateAllKeyStates()
    }

    /// Whether `keyView` takes taps: every key while the keyboard is on, except a greyed-out
    /// return key.
    func isEnabled(_ keyView: KeyboardKeyView) -> Bool {
        isKeyboardEnabled && (keyView.model.kind != .returnKey || isReturnKeyEnabled)
    }

    func setLetterCase(_ letterCase: KeyboardLetterCase) {
        guard letterCase != self.letterCase else { return }
        self.letterCase = letterCase
        currentPage?.apply(letterCase: letterCase, isTrackpadModeActive: spaceTrackpadController.isActive)
    }

    /// Shows the accent key as `label` says, or as the letter layout draws it when nil.
    func setAccentKeyLabel(_ label: KeyboardAccentKeyLabel?) {
        guard label != accentKeyLabel else { return }
        accentKeyLabel = label
        currentPage?.apply(accentKeyLabel: label, isTrackpadModeActive: spaceTrackpadController.isActive)
    }

    /// Whether the keys are hidden while another page shows in the grid's place; the grid keeps
    /// its size, so nothing around it moves.
    var isContentHidden = false {
        didSet {
            guard isContentHidden != oldValue else { return }
            if isContentHidden {
                resetInteractionState()
            }
            isUserInteractionEnabled = isContentHidden == false
            alpha = isContentHidden ? 0 : 1
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
        cancelSwipeTracking()
        touchSessions.removeAll()
        trackpadOriginKeyView = nil
        popupOwnerKeyView = nil
        let hadTrackpad = spaceTrackpadController.cancel()
        compactKeysHoldController.cancel()
        deleteRepeatController.cancel()
        popupView.dismiss()
        cancelHeldKey()
        for keyView in keyViews {
            keyView.resetVisualState()
        }
        // The toolbar leaves trackpad mode with the keys, not at its next refresh.
        if hadTrackpad {
            onSpaceTrackpadEvent?(.cancelled)
        }
    }

    func refreshAppearance() {
        updateAllKeyStates()
        popupView.refreshAppearance()
        heldKeyPopupView.refreshAppearance()
    }

    /// Matches the top-row reference views to the keys' height, which the landscape toolbar
    /// buttons take as their own.
    func setTopRowKeyHeight(_ height: CGFloat) {
        guard let topRowAccessoryReferenceHeightConstraint,
              topRowAccessoryReferenceHeightConstraint.constant != height else { return }
        topRowAccessoryReferenceHeightConstraint.constant = height
    }

    /// Spaces the key rows of the page showing, and of every page shown after it.
    func setRowSpacing(_ spacing: CGFloat) {
        rowSpacing = spacing
        currentPage?.view.spacing = spacing
    }

    /// Gives the keys of the page showing, and of every page shown after it, the Display Zoom.
    func setDisplayZoomScale(_ scale: CGFloat) {
        displayZoomScale = scale
        currentPage?.keyViews.forEach { $0.displayZoomScale = scale }
    }

    func topRowKeyView(for slot: KeyboardTopRowAccessorySlot) -> UIView? {
        guard topRowAccessoryReferenceViews.indices.contains(slot.rawValue) else {
            return nil
        }
        return topRowAccessoryReferenceViews[slot.rawValue]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let isLandscape = KeyboardScreenShape.isWide(self)
        currentPage?.updateRowLayouts(
            isLandscape: isLandscape,
            numberPadWidth: KeyboardNumberPadGeometry.width(
                gridWidth: bounds.width,
                screenWidth: window?.windowScene?.coordinateSpace.bounds.width ?? bounds.width,
                isLandscape: isLandscape
            ),
            gridWidth: bounds.width
        )
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
        let resolvedState: KeyboardKeyView.VisualState = isEnabled(keyView) ? state : .disabled
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
            if isEnabled(keyView) == false {
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
        alpha = isContentHidden ? 0 : 1
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        isMultipleTouchEnabled = true
        backgroundColor = KeyboardStyle.touchableClearColor

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
            topRowAccessoryReferenceStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            topRowAccessoryReferenceStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            topRowAccessoryReferenceStack.topAnchor.constraint(equalTo: topAnchor),
            referenceHeightConstraint,
        ])

        swipeTrailView.frame = bounds
        swipeTrailView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(swipeTrailView)
        configureTouchRouter()
    }

    /// Turns the keys of `outgoingPage` over into those of the page showing, which may be the
    /// same page, while the keys are on screen; with Reduce Motion they crossfade.
    private func flipKeys(from outgoingPage: KeyboardKeyGridPage, direction: KeyboardKeyFlipWave.Direction) {
        guard let page = currentPage, window != nil, isContentHidden == false, bounds.isEmpty == false else {
            return
        }
        // The wave reaches each key by where it lies, so the new keys are laid out first.
        layoutIfNeeded()
        settleLayout(of: page)
        if outgoingPage !== page {
            outgoingPage.view.isHidden = false
        }
        keyFlipTransition.run(
            outgoing: outgoingPage.keyViews,
            incoming: page.keyViews,
            in: self,
            direction: direction,
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        ) { [weak self, weak outgoingPage] in
            guard let self, let outgoingPage, outgoingPage !== self.currentPage else { return }
            outgoingPage.view.isHidden = true
        }
    }

    /// Lays out `page`'s rows and their keys now. They lay out after this view, so until then
    /// their frames are from the previous layout pass.
    private func settleLayout(of page: KeyboardKeyGridPage) {
        page.view.layoutIfNeeded()
        page.view.arrangedSubviews.forEach { $0.layoutIfNeeded() }
    }

    /// Shows the page for the current layout, building it the first time it is needed.
    private func showPage() {
        // A key flip still playing ends here, so its leaving page is hidden before pages change.
        keyFlipTransition.finish()
        cancelAllTouches()
        let layout = KeyboardKeyGridPage.Layout(
            symbolPage: symbolPage,
            keysMode: keysMode,
            isEmojiSearch: isEmojiSearch,
            showsEmojiKey: showsEmojiKey,
            showsNextKeyboardKey: showsNextKeyboardKey,
            fieldKeys: fieldKeys,
            letterLayout: symbolPage == .letters ? KeyboardLetterRows.current.layoutIdentifier : nil
        )
        let page = pages[layout] ?? makePage(for: layout)
        if page !== currentPage {
            currentPage?.view.isHidden = true
            page.view.isHidden = false
            currentPage = page
        }
        page.view.spacing = rowSpacing
        page.keyViews.forEach { $0.displayZoomScale = displayZoomScale }
        page.apply(letterCase: letterCase, isTrackpadModeActive: spaceTrackpadController.isActive)
        page.apply(accentKeyLabel: accentKeyLabel, isTrackpadModeActive: spaceTrackpadController.isActive)
        showLanguageCode()
        updateAllKeyStates()
        setNeedsLayout()
    }

    private func makePage(for layout: KeyboardKeyGridPage.Layout) -> KeyboardKeyGridPage {
        let page = KeyboardKeyGridPage(layout: layout, letterCase: letterCase, keyGridView: self)
        page.view.isHidden = true
        insertSubview(page.view, belowSubview: topRowAccessoryReferenceStack)
        bringSubviewToFront(swipeTrailView)
        NSLayoutConstraint.activate([
            page.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            page.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            page.view.topAnchor.constraint(equalTo: topAnchor),
            page.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        pages[layout] = page
        return page
    }

    private func reportCharacterGeometryIfNeeded() {
        guard symbolPage == .letters else { return }
        // Settled first, or the frames read below are from the previous layout pass.
        currentPage.map(settleLayout(of:))
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
        letterKeyPitch = KeyCenterMap(
            geometry: geometry.map { PredictionKeyGeometry(character: $0.character, frame: $0.frame) }
        ).pitch.width
        onCharacterGeometryChange?(geometry, bounds.size)
    }
}
