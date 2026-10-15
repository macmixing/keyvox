import KeyVoxStyleRewrite
import UIKit

final class KeyboardRootView: UIView {
    private enum Metrics {
        static let infoButtonSize: CGFloat = 44
        static let warningLabelHorizontalInset: CGFloat = 12
    }

    let cancelButton = KeyboardCancelButton()
    let settingsButton = KeyboardSettingsToggleButton()
    let capsLockButton = KeyboardCapsLockButton()
    let speakButton = KeyboardSpeakButton()
    let paragraphButton = KeyboardSettingsToggleButton()
    let listsButton = KeyboardSettingsToggleButton()
    let dictionaryButton = KeyboardSettingsToggleButton()
    let vibesButton = KeyboardVibesButton()
    let logoBarView = KeyboardLogoBarView()
    let keyGridView = KeyboardKeyGridView()
    /// Shown over the key grid, in its place, while the emoji page is open.
    let emojiPageView = KeyboardEmojiPageView()
    /// Shown in the toolbar's place while the emoji page or its search is open.
    let emojiSearchFieldView = KeyboardEmojiSearchFieldView()
    /// Shown above the keys while searching emoji, across the keyboard.
    let emojiSearchResultsView = KeyboardEmojiSearchResultsView()
    let suggestionBarView = KeyboardSuggestionBarView()
    let fullAccessInfoButton = KeyboardHitTargetButton(type: .system)

    private let leadingControlsStack = UIView()
    private let trailingControlsStack = UIView()
    private let centerContainerView = UIView()
    private let contentStack = UIStackView()
    private let mainStack = UIStackView()
    private var mainStackTopConstraint: NSLayoutConstraint?
    /// The search field sits at the top of the keyboard on the emoji page, and over the results
    /// while searching.
    private var emojiSearchFieldAtTopConstraint: NSLayoutConstraint?
    private var emojiSearchFieldOverResultsConstraint: NSLayoutConstraint?
    private let fullAccessWarningContainer = UIView()
    private let fullAccessWarningLabel = UILabel()
    private var leadingControlsWidthConstraint: NSLayoutConstraint?
    private var trailingControlsWidthConstraint: NSLayoutConstraint?
    private var settingsButtonWidthConstraint: NSLayoutConstraint?
    private var settingsButtonHeightConstraint: NSLayoutConstraint?
    private var cancelButtonWidthConstraint: NSLayoutConstraint?
    private var cancelButtonHeightConstraint: NSLayoutConstraint?
    private var capsLockButtonWidthConstraint: NSLayoutConstraint?
    private var capsLockButtonHeightConstraint: NSLayoutConstraint?
    private var keyGridHeightConstraint: NSLayoutConstraint?
    private var topRowAccessoryLayoutGeometry: KeyboardLayoutGeometry.TopRowAccessoryLayout?
    private var suggestionBarLeadingConstraint: NSLayoutConstraint?
    private var suggestionBarTrailingConstraint: NSLayoutConstraint?
    private var isLeftHandedLayoutEnabled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureSubviews()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Sends touches in the keyboard's outer padding, which no other view covers, to the
    /// key grid so they type the nearest key.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        guard hitView == nil || hitView === self || hitView === mainStack else { return hitView }
        let gridPoint = convert(point, to: keyGridView)
        guard keyGridView.isHidden == false,
              emojiPageView.isHidden,
              keyGridView.point(inside: gridPoint, with: event) else {
            return hitView
        }
        return keyGridView
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let showsVibesButton = vibesButton.isHidden == false
        let placeholderSlots = topRowAccessoryLayoutGeometry?.placeholderSlots(
            showsVibesButton: showsVibesButton,
            isLeftHandedLayoutEnabled: isLeftHandedLayoutEnabled
        )
        let leadingPlaceholderSlot = placeholderSlots?.leading ?? KeyboardTopRowAccessorySlot.one
        let trailingPlaceholderSlot = placeholderSlots?.trailing ?? KeyboardTopRowAccessorySlot.zero

        let cancelReferenceWidth = keyGridView.topRowKeyView(for: leadingPlaceholderSlot)?.bounds.width ?? KeyboardStyle.cancelButtonSize
        if cancelReferenceWidth > 0,
           let leadingControlsWidthConstraint,
           let settingsButtonWidthConstraint,
           let settingsButtonHeightConstraint,
           let cancelButtonWidthConstraint,
           let cancelButtonHeightConstraint {
            let buttonHeight = min(cancelReferenceWidth, KeyboardStyle.buttonSize)
            if abs(leadingControlsWidthConstraint.constant - cancelReferenceWidth) > 0.5 ||
                abs(settingsButtonWidthConstraint.constant - cancelReferenceWidth) > 0.5 ||
                abs(settingsButtonHeightConstraint.constant - buttonHeight) > 0.5 ||
                abs(cancelButtonWidthConstraint.constant - cancelReferenceWidth) > 0.5 ||
                abs(cancelButtonHeightConstraint.constant - buttonHeight) > 0.5 {
                leadingControlsWidthConstraint.constant = cancelReferenceWidth
                settingsButtonWidthConstraint.constant = cancelReferenceWidth
                settingsButtonHeightConstraint.constant = buttonHeight
                cancelButtonWidthConstraint.constant = cancelReferenceWidth
                cancelButtonHeightConstraint.constant = buttonHeight
                leadingControlsStack.setNeedsLayout()
                leadingControlsStack.layoutIfNeeded()
                settingsButton.setNeedsLayout()
                settingsButton.layoutIfNeeded()
                cancelButton.setNeedsLayout()
                cancelButton.layoutIfNeeded()
            }
        }

        let capsReferenceWidth = keyGridView.topRowKeyView(for: trailingPlaceholderSlot)?.bounds.width ?? KeyboardStyle.cancelButtonSize
        if capsReferenceWidth > 0,
           let trailingControlsWidthConstraint,
           let capsLockButtonWidthConstraint,
           let capsLockButtonHeightConstraint {
            let buttonHeight = min(capsReferenceWidth, KeyboardStyle.buttonSize)
            if abs(trailingControlsWidthConstraint.constant - capsReferenceWidth) > 0.5 ||
                abs(capsLockButtonWidthConstraint.constant - capsReferenceWidth) > 0.5 ||
                abs(capsLockButtonHeightConstraint.constant - buttonHeight) > 0.5 {
                trailingControlsWidthConstraint.constant = capsReferenceWidth
                capsLockButtonWidthConstraint.constant = capsReferenceWidth
                capsLockButtonHeightConstraint.constant = buttonHeight
                trailingControlsStack.setNeedsLayout()
                trailingControlsStack.layoutIfNeeded()
                capsLockButton.setNeedsLayout()
                capsLockButton.layoutIfNeeded()
            }
        }

        let isLandscape = window?.windowScene?.interfaceOrientation.isLandscape ?? false
        topRowAccessoryLayoutGeometry?.update(
            isLandscape: isLandscape,
            showsVibesButton: showsVibesButton,
            isLeftHandedLayoutEnabled: isLeftHandedLayoutEnabled
        )
        updateSuggestionBarHorizontalConstraints()
    }

    /// Spans the top-row slots from the keyboard's edge to the mic, which swap sides in the
    /// left-handed layout; the settings button hides while the bar shows.
    private func updateSuggestionBarHorizontalConstraints() {
        let slots: (leading: KeyboardTopRowAccessorySlot, trailing: KeyboardTopRowAccessorySlot) =
            isLeftHandedLayoutEnabled ? (.three, .zero) : (.one, .eight)
        guard let leadingReference = keyGridView.topRowKeyView(for: slots.leading),
              let trailingReference = keyGridView.topRowKeyView(for: slots.trailing) else {
            return
        }
        guard suggestionBarLeadingConstraint?.secondItem !== leadingReference
                || suggestionBarTrailingConstraint?.secondItem !== trailingReference else {
            return
        }
        NSLayoutConstraint.deactivate(
            [suggestionBarLeadingConstraint, suggestionBarTrailingConstraint].compactMap { $0 }
        )
        let leading = suggestionBarView.leadingAnchor.constraint(equalTo: leadingReference.leadingAnchor)
        let trailing = suggestionBarView.trailingAnchor.constraint(equalTo: trailingReference.trailingAnchor)
        NSLayoutConstraint.activate([leading, trailing])
        suggestionBarLeadingConstraint = leading
        suggestionBarTrailingConstraint = trailing
    }

    /// Shows the emoji page from under the search field to the key grid's bottom, the field at the
    /// keyboard's top in the toolbar's place, so the keyboard keeps its height; or, while searching,
    /// the field and the results
    /// above the keys, in the room the taller keyboard makes above the toolbar's row, which keeps its
    /// place over the keys.
    private func applyEmojiPanel(_ panel: KeyboardEmojiPanel) {
        let isSearching = panel == .searching
        emojiPageView.isHidden = panel != .browsing
        keyGridView.isContentHidden = panel == .browsing
        keyGridView.allowsSpaceTrackpad = isSearching == false
        emojiSearchFieldView.isHidden = panel == .closed
        emojiSearchFieldView.isSearching = isSearching
        emojiSearchResultsView.isHidden = isSearching == false
        mainStackTopConstraint?.constant = KeyboardStyle.topPadding
            + (isSearching ? KeyboardEmojiSearchGeometry.addedKeyboardHeight : 0)
        emojiSearchFieldAtTopConstraint?.isActive = isSearching == false
        emojiSearchFieldOverResultsConstraint?.isActive = isSearching
    }

    func apply(
        state: KeyboardState,
        symbolPage: KeyboardSymbolPage,
        keysMode: KeyboardKeysMode,
        isLandscape: Bool,
        offersPredictions: Bool,
        isCapsLockEnabled: Bool,
        isDictationCapsApplied: Bool,
        isDictationCapsUppercase: Bool,
        displayedVibeTitle: String,
        displayedVibeStyle: StyleRewriteStyle,
        isDisplayedVibeApplied: Bool,
        isVibesAvailable: Bool,
        isAutoParagraphsEnabled: Bool,
        isListFormattingEnabled: Bool,
        isLeftHandedLayoutEnabled: Bool,
        toolbarMode: KeyboardToolbarMode,
        emojiPanel: KeyboardEmojiPanel,
        showsEmojiKey: Bool,
        showsNextKeyboardKey: Bool,
        isTTSReady: Bool,
        isTrackpadModeActive: Bool
    ) {
        // The emoji search field takes the toolbar's place.
        let showsToolbar = emojiPanel == .closed
        let showsBrandedToolbar = showsToolbar && toolbarMode == .branded
        let warningText = showsToolbar ? toolbarMode.warningText : nil
        let showsToolbarWarning = warningText != nil
        let shouldShowCancel = showsBrandedToolbar && state.showsCancelButton
        // The full keyboard's letter page shows its suggestion bar while predictions are
        // offered (the field allows them and holds letters, and no dictation is still as it
        // landed); the dictation buttons show on the number and symbol pages, in a field without
        // letters or predictions, in Compact Keys, while dictating, and until the user changes
        // the text after a dictation.
        let showsSuggestionBar = showsBrandedToolbar
            && !shouldShowCancel
            && keysMode == .full
            && symbolPage == .letters
            && offersPredictions
        let showsToolbarAccessories = showsBrandedToolbar && !showsSuggestionBar
        let shouldShowSpeak = showsToolbarAccessories && isTTSReady
        let shouldShowVibes = showsToolbarAccessories && isVibesAvailable
        let wasVibesButtonHidden = vibesButton.isHidden
        let shouldEnableSpeak = shouldShowSpeak
            && state != .waitingForApp
            && state != .recording
            && state != .transcribing
        if self.isLeftHandedLayoutEnabled != isLeftHandedLayoutEnabled {
            self.isLeftHandedLayoutEnabled = isLeftHandedLayoutEnabled
            setNeedsLayout()
        }

        settingsButton.isTrackpadModeActive = isTrackpadModeActive
        settingsButton.isEnabled = showsToolbarAccessories && !shouldShowCancel && !isTrackpadModeActive
        settingsButton.isHidden = !showsToolbarAccessories || shouldShowCancel
        speakButton.isHidden = !shouldShowSpeak
        speakButton.alpha = 1
        speakButton.transform = .identity
        
        cancelButton.isEnabled = shouldShowCancel && !isTrackpadModeActive
        cancelButton.isTrackpadModeActive = isTrackpadModeActive
        cancelButton.isHidden = !showsBrandedToolbar || !shouldShowCancel
        cancelButton.alpha = 1
        cancelButton.transform = .identity
        capsLockButton.isLocked = isCapsLockEnabled
        capsLockButton.isDictationCapsApplied = isDictationCapsApplied
        capsLockButton.isDictationCapsUppercase = isDictationCapsUppercase
        capsLockButton.isTrackpadModeActive = isTrackpadModeActive
        capsLockButton.isEnabled = showsToolbarAccessories && !isTrackpadModeActive
        capsLockButton.isHidden = !showsToolbarAccessories
        paragraphButton.isOn = isAutoParagraphsEnabled
        paragraphButton.isTrackpadModeActive = isTrackpadModeActive
        paragraphButton.isEnabled = showsToolbarAccessories && !isTrackpadModeActive
        paragraphButton.isHidden = !showsToolbarAccessories
        listsButton.isOn = isListFormattingEnabled
        listsButton.isTrackpadModeActive = isTrackpadModeActive
        listsButton.isEnabled = showsToolbarAccessories && !isTrackpadModeActive
        listsButton.isHidden = !showsToolbarAccessories
        dictionaryButton.isTrackpadModeActive = isTrackpadModeActive
        dictionaryButton.isEnabled = showsToolbarAccessories && !isTrackpadModeActive
        dictionaryButton.isHidden = !showsToolbarAccessories
        suggestionBarView.isHidden = !showsSuggestionBar
        suggestionBarView.isUserInteractionEnabled = showsSuggestionBar && !isTrackpadModeActive
        vibesButton.isTrackpadModeActive = isTrackpadModeActive
        vibesButton.isEnabled = shouldShowVibes && !isTrackpadModeActive
        vibesButton.isHidden = !shouldShowVibes
        vibesButton.title = displayedVibeTitle
        vibesButton.displayedVibeStyle = displayedVibeStyle
        vibesButton.isDisplayedVibeApplied = isDisplayedVibeApplied
        speakButton.isSpeaking = state.isTTSPlaybackActive
        speakButton.isTrackpadModeActive = isTrackpadModeActive
        speakButton.isEnabled = shouldEnableSpeak && !isTrackpadModeActive

        // Keep the toolbar row containers visible even when the toolbar content is hidden.
        // Hiding the arranged containers causes the top row to collapse and the key grid to
        // jump, which shows up as a flash in the unconfigured keyboard state.
        leadingControlsStack.isHidden = false
        trailingControlsStack.isHidden = false
        centerContainerView.isHidden = false

        logoBarView.isHidden = !showsBrandedToolbar
        fullAccessWarningLabel.text = warningText
        fullAccessWarningContainer.isHidden = !showsToolbarWarning
        fullAccessInfoButton.isHidden = !showsToolbar || !toolbarMode.showsWarningInfoButton
        fullAccessInfoButton.isEnabled = showsToolbar && toolbarMode.showsWarningInfoButton
        logoBarView.applyKeyboardState(state)
        logoBarView.isEnabled = showsBrandedToolbar && state.isIndicatorEnabled

        applyEmojiPanel(emojiPanel)
        keyGridView.setLayout(
            symbolPage: symbolPage,
            keysMode: keysMode,
            isEmojiSearch: emojiPanel == .searching,
            showsEmojiKey: showsEmojiKey,
            showsNextKeyboardKey: showsNextKeyboardKey
        )
        keyGridHeightConstraint?.constant = keysMode.keyGridHeight(isLandscape: isLandscape)
        keyGridView.setTopRowKeyHeight(keysMode.keyHeight(isLandscape: isLandscape))
        keyGridView.setKeyboardEnabled(true)
        keyGridView.refreshAppearance()

        if vibesButton.isHidden != wasVibesButtonHidden {
            setNeedsLayout()
        }
    }

    private func configureView() {
        backgroundColor = KeyboardStyle.touchableClearColor
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureSubviews() {
        cancelButton.isHidden = true
        cancelButton.alpha = 1
        cancelButton.transform = .identity
        settingsButton.symbolName = "gearshape.fill"
        settingsButton.accessibilityTitle = "Settings"
        settingsButton.showsStateValue = false
        settingsButton.isHidden = true
        speakButton.isHidden = true
        speakButton.alpha = 1
        speakButton.transform = .identity
        vibesButton.isHidden = true
        paragraphButton.symbolName = "text.alignleft"
        paragraphButton.accessibilityTitle = "Paragraphs"
        paragraphButton.isHidden = true
        listsButton.symbolName = "list.number"
        listsButton.accessibilityTitle = "Lists"
        listsButton.isHidden = true
        dictionaryButton.symbolName = "text.book.closed.fill"
        dictionaryButton.accessibilityTitle = "Dictionary"
        dictionaryButton.showsStateValue = false
        dictionaryButton.isHidden = true
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        capsLockButton.translatesAutoresizingMaskIntoConstraints = false
        speakButton.translatesAutoresizingMaskIntoConstraints = false
        paragraphButton.translatesAutoresizingMaskIntoConstraints = false
        listsButton.translatesAutoresizingMaskIntoConstraints = false
        dictionaryButton.translatesAutoresizingMaskIntoConstraints = false
        vibesButton.translatesAutoresizingMaskIntoConstraints = false

        logoBarView.translatesAutoresizingMaskIntoConstraints = false

        fullAccessWarningContainer.translatesAutoresizingMaskIntoConstraints = false
        fullAccessWarningContainer.isHidden = true

        fullAccessWarningLabel.translatesAutoresizingMaskIntoConstraints = false
        fullAccessWarningLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        fullAccessWarningLabel.textColor = .systemRed
        fullAccessWarningLabel.textAlignment = .center
        fullAccessWarningLabel.numberOfLines = 1
        fullAccessWarningLabel.text = "Allow Full Access for dictation"
        fullAccessWarningLabel.adjustsFontSizeToFitWidth = true
        fullAccessWarningLabel.minimumScaleFactor = 0.8
        fullAccessWarningLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        fullAccessInfoButton.translatesAutoresizingMaskIntoConstraints = false
        fullAccessInfoButton.backgroundColor = UIColor.white.withAlphaComponent(0.001)
        fullAccessInfoButton.tintColor = .label
        fullAccessInfoButton.setImage(
            UIImage(
                systemName: "info.circle",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            ),
            for: .normal
        )
        fullAccessInfoButton.accessibilityLabel = "Full Access instructions"
        fullAccessInfoButton.isHidden = true

        centerContainerView.translatesAutoresizingMaskIntoConstraints = false

        leadingControlsStack.translatesAutoresizingMaskIntoConstraints = false
        trailingControlsStack.translatesAutoresizingMaskIntoConstraints = false

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.distribution = .fill
        contentStack.spacing = KeyboardStyle.stackSpacing

        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.distribution = .fill
        mainStack.spacing = KeyboardStyle.sectionSpacing
        mainStack.clipsToBounds = false

        addSubview(mainStack)
        emojiPageView.translatesAutoresizingMaskIntoConstraints = false
        emojiPageView.isHidden = true
        addSubview(emojiPageView)
        addSubview(capsLockButton)
        addSubview(paragraphButton)
        addSubview(listsButton)
        addSubview(dictionaryButton)
        addSubview(vibesButton)
        addSubview(speakButton)
        suggestionBarView.isHidden = true
        addSubview(suggestionBarView)
        addSubview(logoBarView)
        addSubview(settingsButton)
        addSubview(cancelButton)

        addSubview(fullAccessWarningContainer)
        emojiSearchFieldView.translatesAutoresizingMaskIntoConstraints = false
        emojiSearchFieldView.isHidden = true
        addSubview(emojiSearchFieldView)
        emojiSearchResultsView.translatesAutoresizingMaskIntoConstraints = false
        emojiSearchResultsView.isHidden = true
        addSubview(emojiSearchResultsView)

        fullAccessWarningContainer.addSubview(fullAccessWarningLabel)
        fullAccessWarningContainer.addSubview(fullAccessInfoButton)

        contentStack.addArrangedSubview(leadingControlsStack)
        contentStack.addArrangedSubview(centerContainerView)
        contentStack.addArrangedSubview(trailingControlsStack)

        mainStack.addArrangedSubview(contentStack)
        mainStack.addArrangedSubview(keyGridView)

        keyGridView.clipsToBounds = false
    }

    private func configureLayout() {
        leadingControlsWidthConstraint = leadingControlsStack.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize)
        trailingControlsWidthConstraint = trailingControlsStack.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize)
        let cancelButtonLeadingConstraint = cancelButton.leadingAnchor.constraint(equalTo: leadingControlsStack.leadingAnchor)
        let cancelButtonCenterYConstraint = cancelButton.centerYAnchor.constraint(
            equalTo: leadingControlsStack.centerYAnchor
        )
        let settingsButtonLeadingConstraint = settingsButton.leadingAnchor.constraint(equalTo: leadingControlsStack.leadingAnchor)
        let settingsButtonCenterYConstraint = settingsButton.centerYAnchor.constraint(
            equalTo: leadingControlsStack.centerYAnchor
        )
        settingsButtonWidthConstraint = settingsButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)
        settingsButtonHeightConstraint = settingsButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)
        cancelButtonWidthConstraint = cancelButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)
        cancelButtonHeightConstraint = cancelButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)
        let capsLockButtonTrailingConstraint = capsLockButton.trailingAnchor.constraint(equalTo: trailingControlsStack.trailingAnchor)
        let capsLockButtonCenterYConstraint = capsLockButton.centerYAnchor.constraint(
            equalTo: trailingControlsStack.centerYAnchor
        )
        capsLockButtonWidthConstraint = capsLockButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)
        capsLockButtonHeightConstraint = capsLockButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)

        keyGridHeightConstraint = keyGridView.heightAnchor.constraint(
            equalToConstant: KeyboardKeysMode.full.keyGridHeight(isLandscape: false)
        )

        NSLayoutConstraint.activate([
            // Fixed width for both control containers ensures the logo stays perfectly centered
            // regardless of button visibility or individual button sizes.
            leadingControlsWidthConstraint!,
            trailingControlsWidthConstraint!,
            leadingControlsStack.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            trailingControlsStack.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),

            // Leading action buttons are flush with the left edge of their container.
            settingsButtonWidthConstraint!,
            settingsButtonHeightConstraint!,
            settingsButtonLeadingConstraint,
            settingsButtonCenterYConstraint,
            cancelButtonWidthConstraint!,
            cancelButtonHeightConstraint!,
            cancelButtonLeadingConstraint,
            cancelButtonCenterYConstraint,

            fullAccessWarningContainer.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            fullAccessWarningContainer.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            fullAccessWarningContainer.topAnchor.constraint(equalTo: contentStack.topAnchor),
            fullAccessWarningContainer.bottomAnchor.constraint(equalTo: contentStack.bottomAnchor),

            fullAccessInfoButton.widthAnchor.constraint(equalToConstant: Metrics.infoButtonSize),
            fullAccessInfoButton.heightAnchor.constraint(equalTo: fullAccessInfoButton.widthAnchor),
            fullAccessInfoButton.trailingAnchor.constraint(equalTo: fullAccessWarningContainer.trailingAnchor),
            fullAccessInfoButton.centerYAnchor.constraint(equalTo: fullAccessWarningContainer.centerYAnchor),

            fullAccessWarningLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: fullAccessWarningContainer.leadingAnchor,
                constant: Metrics.warningLabelHorizontalInset
            ),
            fullAccessWarningLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: fullAccessInfoButton.leadingAnchor,
                constant: -Metrics.warningLabelHorizontalInset
            ),
            fullAccessWarningLabel.centerXAnchor.constraint(equalTo: fullAccessWarningContainer.centerXAnchor),
            fullAccessWarningLabel.centerYAnchor.constraint(equalTo: fullAccessWarningContainer.centerYAnchor),
            suggestionBarView.centerYAnchor.constraint(equalTo: capsLockButton.centerYAnchor),
            suggestionBarView.heightAnchor.constraint(equalTo: capsLockButton.heightAnchor),
            centerContainerView.widthAnchor.constraint(greaterThanOrEqualTo: logoBarView.widthAnchor),
            centerContainerView.heightAnchor.constraint(greaterThanOrEqualTo: logoBarView.heightAnchor),

            keyGridHeightConstraint!,

            emojiSearchFieldView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: KeyboardEmojiSearchGeometry.Measured.fieldInset
            ),
            emojiSearchFieldView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -KeyboardEmojiSearchGeometry.Measured.fieldInset
            ),
            emojiSearchFieldView.heightAnchor.constraint(equalToConstant: KeyboardEmojiSearchGeometry.Measured.fieldHeight),

            emojiSearchResultsView.leadingAnchor.constraint(equalTo: leadingAnchor),
            emojiSearchResultsView.trailingAnchor.constraint(equalTo: trailingAnchor),
            emojiSearchResultsView.bottomAnchor.constraint(
                equalTo: keyGridView.topAnchor,
                constant: -KeyboardEmojiSearchGeometry.Measured.resultsGapAboveKeys
            ),
            emojiSearchResultsView.heightAnchor.constraint(equalToConstant: KeyboardEmojiSearchGeometry.Measured.resultsHeight),

            emojiPageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            emojiPageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            emojiPageView.topAnchor.constraint(
                equalTo: emojiSearchFieldView.bottomAnchor,
                constant: KeyboardEmojiSearchGeometry.Measured.pageGapBelowField
            ),
            emojiPageView.bottomAnchor.constraint(equalTo: keyGridView.bottomAnchor),

            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KeyboardStyle.horizontalPadding),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -KeyboardStyle.horizontalPadding),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -KeyboardStyle.bottomPadding),
        ])

        let mainStackTopConstraint = mainStack.topAnchor.constraint(equalTo: topAnchor, constant: KeyboardStyle.topPadding)
        mainStackTopConstraint.isActive = true
        self.mainStackTopConstraint = mainStackTopConstraint
        // As far from the keyboard's top as the toolbar's row sits.
        let fieldAtTop = emojiSearchFieldView.topAnchor.constraint(equalTo: topAnchor, constant: KeyboardStyle.topPadding)
        fieldAtTop.isActive = true
        emojiSearchFieldAtTopConstraint = fieldAtTop
        emojiSearchFieldOverResultsConstraint = emojiSearchFieldView.bottomAnchor.constraint(
            equalTo: emojiSearchResultsView.topAnchor,
            constant: -KeyboardEmojiSearchGeometry.Measured.resultsGapBelowField
        )

        if let cancelButtonWidthConstraint,
           let cancelButtonHeightConstraint,
           let settingsButtonWidthConstraint,
           let settingsButtonHeightConstraint,
           let capsLockButtonWidthConstraint,
           let capsLockButtonHeightConstraint {
            topRowAccessoryLayoutGeometry = KeyboardLayoutGeometry.TopRowAccessoryLayout(
                cancelButton: cancelButton,
                settingsButton: settingsButton,
                capsLockButton: capsLockButton,
                speakButton: speakButton,
                paragraphButton: paragraphButton,
                listsButton: listsButton,
                dictionaryButton: dictionaryButton,
                vibesButton: vibesButton,
                logoBarView: logoBarView,
                keyGridView: keyGridView,
                cancelButtonLeadingConstraint: cancelButtonLeadingConstraint,
                settingsButtonLeadingConstraint: settingsButtonLeadingConstraint,
                capsLockButtonTrailingConstraint: capsLockButtonTrailingConstraint,
                cancelButtonCenterYConstraint: cancelButtonCenterYConstraint,
                settingsButtonCenterYConstraint: settingsButtonCenterYConstraint,
                capsLockButtonCenterYConstraint: capsLockButtonCenterYConstraint,
                cancelButtonWidthConstraint: cancelButtonWidthConstraint,
                cancelButtonHeightConstraint: cancelButtonHeightConstraint,
                settingsButtonWidthConstraint: settingsButtonWidthConstraint,
                settingsButtonHeightConstraint: settingsButtonHeightConstraint,
                capsLockButtonWidthConstraint: capsLockButtonWidthConstraint,
                capsLockButtonHeightConstraint: capsLockButtonHeightConstraint
            )
        }
    }

}
