import UIKit

final class KeyboardRootView: UIView {
    private enum Metrics {
        static let topRowSideControlVerticalOffset: CGFloat = 10
        static let infoButtonSize: CGFloat = 44
        static let warningLabelHorizontalInset: CGFloat = 12
    }

    let cancelButton = KeyboardCancelButton()
    let capsLockButton = KeyboardCapsLockButton()
    let speakButton = KeyboardSpeakButton()
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
    private var cancelButtonWidthConstraint: NSLayoutConstraint?
    private var cancelButtonHeightConstraint: NSLayoutConstraint?
    private var capsLockButtonWidthConstraint: NSLayoutConstraint?
    private var capsLockButtonHeightConstraint: NSLayoutConstraint?
    private var topRowAccessoryLayoutGeometry: KeyboardLayoutGeometry.TopRowAccessoryLayout?
    private var cancelButtonVisibilityTarget = false
    private var speakButtonVisibilityTarget = false
    private var hasAppliedInitialSpeakVisibility = false

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

        let cancelReferenceWidth = keyGridView.topRowKeyView(for: .one)?.bounds.width ?? KeyboardStyle.cancelButtonSize
        if cancelReferenceWidth > 0,
           let leadingControlsWidthConstraint,
           let cancelButtonWidthConstraint,
           let cancelButtonHeightConstraint {
            let buttonHeight = min(cancelReferenceWidth, KeyboardStyle.buttonSize)
            if abs(leadingControlsWidthConstraint.constant - cancelReferenceWidth) > 0.5 ||
                abs(cancelButtonWidthConstraint.constant - cancelReferenceWidth) > 0.5 ||
                abs(cancelButtonHeightConstraint.constant - buttonHeight) > 0.5 {
                leadingControlsWidthConstraint.constant = cancelReferenceWidth
                cancelButtonWidthConstraint.constant = cancelReferenceWidth
                cancelButtonHeightConstraint.constant = buttonHeight
                leadingControlsStack.setNeedsLayout()
                leadingControlsStack.layoutIfNeeded()
                cancelButton.setNeedsLayout()
                cancelButton.layoutIfNeeded()
            }
        }

        let capsReferenceWidth = keyGridView.topRowKeyView(for: .zero)?.bounds.width ?? KeyboardStyle.cancelButtonSize
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
        topRowAccessoryLayoutGeometry?.update(isLandscape: isLandscape)
    }

    func apply(
        state: KeyboardState,
        symbolPage: KeyboardSymbolPage,
        isCapsLockEnabled: Bool,
        toolbarMode: KeyboardToolbarMode,
        isTrackpadModeActive: Bool
    ) {
        let showsBrandedToolbar = toolbarMode == .branded
        let warningText = toolbarMode.warningText
        let showsToolbarWarning = warningText != nil
        let shouldShowCancel = showsBrandedToolbar && state.showsCancelButton
        let shouldShowSpeak = showsBrandedToolbar && !state.showsCancelButton

        if shouldShowCancel != cancelButtonVisibilityTarget {
            cancelButtonVisibilityTarget = shouldShowCancel
            cancelButton.layer.removeAllAnimations()

            if shouldShowCancel {
                cancelButton.alpha = 0
                cancelButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                cancelButton.isHidden = false

                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .allowUserInteraction, animations: {
                    self.cancelButton.alpha = 1
                    self.cancelButton.transform = .identity
                })
            } else {
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .allowUserInteraction, animations: {
                    self.cancelButton.alpha = 0
                    self.cancelButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                }) { _ in
                    guard !self.cancelButtonVisibilityTarget else { return }
                    self.cancelButton.isHidden = true
                    self.cancelButton.alpha = 1
                    self.cancelButton.transform = .identity
                }
            }
        }

        if shouldShowSpeak != speakButtonVisibilityTarget {
            speakButtonVisibilityTarget = shouldShowSpeak

            if hasAppliedInitialSpeakVisibility == false {
                hasAppliedInitialSpeakVisibility = true
                if shouldShowSpeak {
                    speakButton.isHidden = false
                } else {
                    speakButton.isHidden = true
                }
            } else {
                speakButton.layer.removeAllAnimations()

                if shouldShowSpeak {
                    speakButton.alpha = 0
                    speakButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                    speakButton.isHidden = false

                    UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .allowUserInteraction, animations: {
                        self.speakButton.alpha = 1
                        self.speakButton.transform = .identity
                    })
                } else {
                    UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .allowUserInteraction, animations: {
                        self.speakButton.alpha = 0
                        self.speakButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                    }) { _ in
                        guard !self.speakButtonVisibilityTarget else { return }
                        self.speakButton.isHidden = true
                        self.speakButton.alpha = 1
                        self.speakButton.transform = .identity
                    }
                }
            }
        }
        
        cancelButton.isEnabled = shouldShowCancel && !isTrackpadModeActive
        cancelButton.isTrackpadModeActive = isTrackpadModeActive
        capsLockButton.isLocked = isCapsLockEnabled
        capsLockButton.isTrackpadModeActive = isTrackpadModeActive
        capsLockButton.isEnabled = showsBrandedToolbar && !isTrackpadModeActive
        capsLockButton.isHidden = !showsBrandedToolbar
        speakButton.isSpeaking = state == .speaking
        speakButton.isTrackpadModeActive = isTrackpadModeActive
        speakButton.isEnabled = shouldShowSpeak && !isTrackpadModeActive

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
        logoBarView.applyIndicatorPhase(state.indicatorPhase)
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
        speakButton.isHidden = true
        speakButton.alpha = 1
        speakButton.transform = .identity
        capsLockButton.translatesAutoresizingMaskIntoConstraints = false
        speakButton.translatesAutoresizingMaskIntoConstraints = false

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
        addSubview(speakButton)

        addSubview(fullAccessWarningContainer)
        
        // Keep special toolbar controls outside the keyboard grid so the logo can stay
        // vertically centered while those controls align visually with the top row.
        // This preserves the current keyboard height and keeps toolbar positioning
        // independent from grid layout rules.
        leadingControlsStack.addSubview(cancelButton)
        trailingControlsStack.addSubview(capsLockButton)
        
        centerContainerView.addSubview(logoBarView)

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
            equalTo: leadingControlsStack.centerYAnchor,
            constant: Metrics.topRowSideControlVerticalOffset
        )
        cancelButtonWidthConstraint = cancelButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)
        cancelButtonHeightConstraint = cancelButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)
        let capsLockButtonTrailingConstraint = capsLockButton.trailingAnchor.constraint(equalTo: trailingControlsStack.trailingAnchor)
        let capsLockButtonCenterYConstraint = capsLockButton.centerYAnchor.constraint(
            equalTo: trailingControlsStack.centerYAnchor,
            constant: Metrics.topRowSideControlVerticalOffset
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

            // Cancel button flush with the left edge of its container
            cancelButtonWidthConstraint!,
            cancelButtonHeightConstraint!,
            cancelButtonLeadingConstraint,
            cancelButtonCenterYConstraint,

            capsLockButtonWidthConstraint!,
            capsLockButtonHeightConstraint!,
            capsLockButtonTrailingConstraint,
            capsLockButtonCenterYConstraint,

            fullAccessWarningContainer.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            fullAccessWarningContainer.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            fullAccessWarningContainer.topAnchor.constraint(equalTo: contentStack.topAnchor),
            fullAccessWarningContainer.bottomAnchor.constraint(equalTo: contentStack.bottomAnchor),

            fullAccessInfoButton.widthAnchor.constraint(equalToConstant: Metrics.infoButtonSize),
            fullAccessInfoButton.heightAnchor.constraint(equalTo: fullAccessInfoButton.widthAnchor),
            fullAccessInfoButton.trailingAnchor.constraint(equalTo: fullAccessWarningContainer.trailingAnchor),
            fullAccessInfoButton.centerYAnchor.constraint(
                equalTo: fullAccessWarningContainer.centerYAnchor,
                constant: Metrics.topRowSideControlVerticalOffset
            ),

            logoBarView.centerXAnchor.constraint(equalTo: centerContainerView.centerXAnchor),
            logoBarView.centerYAnchor.constraint(equalTo: centerContainerView.centerYAnchor),
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
           let capsLockButtonWidthConstraint,
           let capsLockButtonHeightConstraint {
            topRowAccessoryLayoutGeometry = KeyboardLayoutGeometry.TopRowAccessoryLayout(
                cancelButton: cancelButton,
                capsLockButton: capsLockButton,
                speakButton: speakButton,
                keyGridView: keyGridView,
                cancelButtonLeadingConstraint: cancelButtonLeadingConstraint,
                capsLockButtonTrailingConstraint: capsLockButtonTrailingConstraint,
                cancelButtonCenterYConstraint: cancelButtonCenterYConstraint,
                capsLockButtonCenterYConstraint: capsLockButtonCenterYConstraint,
                cancelButtonWidthConstraint: cancelButtonWidthConstraint,
                cancelButtonHeightConstraint: cancelButtonHeightConstraint,
                capsLockButtonWidthConstraint: capsLockButtonWidthConstraint,
                capsLockButtonHeightConstraint: capsLockButtonHeightConstraint
            )
        }
    }

}
