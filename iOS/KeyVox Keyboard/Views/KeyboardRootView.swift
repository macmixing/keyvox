import UIKit

final class KeyboardRootView: UIView {
    private enum Metrics {
        static let topRowSideControlVerticalOffset: CGFloat = 10
        static let infoButtonSize: CGFloat = 44
        static let warningLabelHorizontalInset: CGFloat = 12
    }

    let cancelButton = KeyboardCancelButton()
    let capsLockButton = KeyboardCapsLockButton()
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
    private var cancelButtonWidthConstraint: NSLayoutConstraint?
    private var capsLockButtonWidthConstraint: NSLayoutConstraint?
    private var cancelButtonVisibilityTarget = false

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
           let cancelButtonWidthConstraint,
           abs(cancelButtonWidthConstraint.constant - cancelReferenceWidth) > 0.5 {
            cancelButtonWidthConstraint.constant = cancelReferenceWidth
            leadingControlsStack.setNeedsLayout()
            leadingControlsStack.layoutIfNeeded()
            cancelButton.setNeedsLayout()
            cancelButton.layoutIfNeeded()
        }

        let capsReferenceWidth = keyGridView.topRowKeyView(for: .zero)?.bounds.width ?? KeyboardStyle.cancelButtonSize
        if capsReferenceWidth > 0,
           let capsLockButtonWidthConstraint,
           abs(capsLockButtonWidthConstraint.constant - capsReferenceWidth) > 0.5 {
            capsLockButtonWidthConstraint.constant = capsReferenceWidth
            trailingControlsStack.setNeedsLayout()
            trailingControlsStack.layoutIfNeeded()
            capsLockButton.setNeedsLayout()
            capsLockButton.layoutIfNeeded()
        }
    }

    func apply(
        state: KeyboardState,
        symbolPage: KeyboardSymbolPage,
        isCapsLockEnabled: Bool,
        toolbarMode: KeyboardToolbarMode,
        isTrackpadModeActive: Bool
    ) {
        let showsToolbar = toolbarMode != .hidden
        let showsBrandedToolbar = toolbarMode == .branded
        let showsFullAccessWarning = toolbarMode == .fullAccessWarning
        let shouldShowCancel = showsBrandedToolbar && state.showsCancelButton

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
        
        cancelButton.isEnabled = shouldShowCancel && !isTrackpadModeActive
        cancelButton.isTrackpadModeActive = isTrackpadModeActive
        capsLockButton.isLocked = isCapsLockEnabled
        capsLockButton.isTrackpadModeActive = isTrackpadModeActive
        capsLockButton.isEnabled = showsBrandedToolbar && !isTrackpadModeActive
        capsLockButton.isHidden = !showsBrandedToolbar
        leadingControlsStack.isHidden = !showsToolbar
        trailingControlsStack.isHidden = !showsToolbar
        centerContainerView.isHidden = !showsToolbar
        logoBarView.isHidden = !showsBrandedToolbar
        fullAccessWarningContainer.isHidden = !showsFullAccessWarning
        fullAccessInfoButton.isHidden = !showsFullAccessWarning
        fullAccessInfoButton.isEnabled = showsFullAccessWarning
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
        capsLockButton.translatesAutoresizingMaskIntoConstraints = false

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
        cancelButtonWidthConstraint = cancelButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)
        capsLockButtonWidthConstraint = capsLockButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)

        NSLayoutConstraint.activate([
            // Fixed width for both control containers ensures the logo stays perfectly centered
            // regardless of button visibility or individual button sizes.
            leadingControlsStack.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            trailingControlsStack.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            leadingControlsStack.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            trailingControlsStack.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),

            // Cancel button flush with the left edge of its container
            cancelButtonWidthConstraint!,
            cancelButton.heightAnchor.constraint(equalTo: cancelButton.widthAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: leadingControlsStack.leadingAnchor),
            cancelButton.centerYAnchor.constraint(
                equalTo: leadingControlsStack.centerYAnchor,
                constant: Metrics.topRowSideControlVerticalOffset
            ),

            capsLockButtonWidthConstraint!,
            capsLockButton.heightAnchor.constraint(equalTo: cancelButton.heightAnchor),
            capsLockButton.trailingAnchor.constraint(equalTo: trailingControlsStack.trailingAnchor),
            capsLockButton.centerYAnchor.constraint(
                equalTo: trailingControlsStack.centerYAnchor,
                constant: Metrics.topRowSideControlVerticalOffset
            ),

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
    }

}
