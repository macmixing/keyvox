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
    let fullAccessInfoButton = KeyboardHitTargetButton(type: .system)

    private let leadingControlsStack = UIView()
    private let trailingControlsStack = UIView()
    private let centerContainerView = UIView()
    private let contentStack = UIStackView()
    private let mainStack = UIStackView()
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
    private var topRowAccessoryLayoutGeometry: KeyboardLayoutGeometry.TopRowAccessoryLayout?
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
    }

    func apply(
        state: KeyboardState,
        symbolPage: KeyboardSymbolPage,
        isCapsLockEnabled: Bool,
        selectedVibeTitle: String,
        selectedVibeStyle: StyleRewriteStyle,
        isVibesAvailable: Bool,
        isAutoParagraphsEnabled: Bool,
        isListFormattingEnabled: Bool,
        isLeftHandedLayoutEnabled: Bool,
        toolbarMode: KeyboardToolbarMode,
        isTTSReady: Bool,
        isTrackpadModeActive: Bool
    ) {
        let showsBrandedToolbar = toolbarMode == .branded
        let warningText = toolbarMode.warningText
        let showsToolbarWarning = warningText != nil
        let shouldShowCancel = showsBrandedToolbar && state.showsCancelButton
        let shouldShowSpeak = showsBrandedToolbar && isTTSReady
        let shouldEnableSpeak = shouldShowSpeak
            && state != .waitingForApp
            && state != .recording
            && state != .transcribing
        if self.isLeftHandedLayoutEnabled != isLeftHandedLayoutEnabled {
            self.isLeftHandedLayoutEnabled = isLeftHandedLayoutEnabled
            setNeedsLayout()
        }

        settingsButton.isTrackpadModeActive = isTrackpadModeActive
        settingsButton.isEnabled = showsBrandedToolbar && !shouldShowCancel && !isTrackpadModeActive
        settingsButton.isHidden = !showsBrandedToolbar || shouldShowCancel
        speakButton.isHidden = !shouldShowSpeak
        speakButton.alpha = 1
        speakButton.transform = .identity
        
        cancelButton.isEnabled = shouldShowCancel && !isTrackpadModeActive
        cancelButton.isTrackpadModeActive = isTrackpadModeActive
        cancelButton.isHidden = !showsBrandedToolbar || !shouldShowCancel
        cancelButton.alpha = 1
        cancelButton.transform = .identity
        capsLockButton.isLocked = isCapsLockEnabled
        capsLockButton.isTrackpadModeActive = isTrackpadModeActive
        capsLockButton.isEnabled = showsBrandedToolbar && !isTrackpadModeActive
        capsLockButton.isHidden = !showsBrandedToolbar
        paragraphButton.isOn = isAutoParagraphsEnabled
        paragraphButton.isTrackpadModeActive = isTrackpadModeActive
        paragraphButton.isEnabled = showsBrandedToolbar && !isTrackpadModeActive
        paragraphButton.isHidden = !showsBrandedToolbar
        listsButton.isOn = isListFormattingEnabled
        listsButton.isTrackpadModeActive = isTrackpadModeActive
        listsButton.isEnabled = showsBrandedToolbar && !isTrackpadModeActive
        listsButton.isHidden = !showsBrandedToolbar
        dictionaryButton.isTrackpadModeActive = isTrackpadModeActive
        dictionaryButton.isEnabled = showsBrandedToolbar && !isTrackpadModeActive
        dictionaryButton.isHidden = !showsBrandedToolbar
        vibesButton.isTrackpadModeActive = isTrackpadModeActive
        vibesButton.isEnabled = showsBrandedToolbar && isVibesAvailable && !isTrackpadModeActive
        vibesButton.isHidden = !showsBrandedToolbar || !isVibesAvailable
        vibesButton.title = selectedVibeTitle
        vibesButton.selectedVibeStyle = selectedVibeStyle
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
        fullAccessInfoButton.isHidden = !toolbarMode.showsWarningInfoButton
        fullAccessInfoButton.isEnabled = toolbarMode.showsWarningInfoButton
        logoBarView.applyKeyboardState(state)
        logoBarView.isEnabled = showsBrandedToolbar && state.isIndicatorEnabled

        keyGridView.setSymbolPage(symbolPage)
        keyGridView.setKeyboardEnabled(true)
        keyGridView.refreshAppearance()
    }

    private func configureView() {
        backgroundColor = .clear
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
        addSubview(capsLockButton)
        addSubview(paragraphButton)
        addSubview(listsButton)
        addSubview(dictionaryButton)
        addSubview(vibesButton)
        addSubview(speakButton)
        addSubview(logoBarView)
        addSubview(settingsButton)
        addSubview(cancelButton)

        addSubview(fullAccessWarningContainer)

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
            centerContainerView.widthAnchor.constraint(greaterThanOrEqualTo: logoBarView.widthAnchor),
            centerContainerView.heightAnchor.constraint(greaterThanOrEqualTo: logoBarView.heightAnchor),

            keyGridView.heightAnchor.constraint(equalToConstant: KeyboardStyle.keyHeight * 4 + KeyboardStyle.keyboardRowSpacing * 3),

            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KeyboardStyle.horizontalPadding),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -KeyboardStyle.horizontalPadding),
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: KeyboardStyle.topPadding),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -KeyboardStyle.bottomPadding),
        ])

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
