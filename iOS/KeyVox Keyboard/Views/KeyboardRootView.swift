import UIKit

final class KeyboardRootView: UIView {
    private enum Metrics {
        static let topRowSideControlVerticalOffset: CGFloat = 10
    }

    let cancelButton = KeyboardCancelButton()
    let nextKeyboardButton = UIButton(type: .system)
    let logoBarView = KeyboardLogoBarView()
    let keyGridView = KeyboardKeyGridView()

    private let leadingControlsStack = UIView()
    private let trailingControlsStack = UIView()
    private let centerContainerView = UIView()
    private let contentStack = UIStackView()
    private let mainStack = UIStackView()
    private var cancelButtonWidthConstraint: NSLayoutConstraint?
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

        let referenceWidth = keyGridView.topRowKeyView(for: .one)?.bounds.width ?? KeyboardStyle.cancelButtonSize
        guard referenceWidth > 0 else { return }
        guard let cancelButtonWidthConstraint else { return }
        if abs(cancelButtonWidthConstraint.constant - referenceWidth) > 0.5 {
            cancelButtonWidthConstraint.constant = referenceWidth
            leadingControlsStack.setNeedsLayout()
            leadingControlsStack.layoutIfNeeded()
            cancelButton.setNeedsLayout()
            cancelButton.layoutIfNeeded()
        }
    }

    func apply(state: KeyboardState, showsNextKeyboard: Bool, symbolPage: KeyboardSymbolPage) {
        let shouldShowCancel = state.showsCancelButton

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
        
        cancelButton.isEnabled = shouldShowCancel
        nextKeyboardButton.isHidden = !showsNextKeyboard
        nextKeyboardButton.isEnabled = showsNextKeyboard

        logoBarView.applyIndicatorPhase(state.indicatorPhase)
        logoBarView.isEnabled = state.isIndicatorEnabled

        keyGridView.setSymbolPage(symbolPage)
        keyGridView.setKeyboardEnabled(true)
    }

    private func configureView() {
        backgroundColor = .clear
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureSubviews() {
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButton.tintColor = KeyboardStyle.labelColor
        nextKeyboardButton.backgroundColor = KeyboardStyle.buttonFillColor
        nextKeyboardButton.layer.cornerRadius = KeyboardStyle.buttonCornerRadius
        nextKeyboardButton.setImage(
            UIImage(systemName: "globe", withConfiguration: KeyboardStyle.buttonSymbolConfiguration),
            for: .normal
        )
        nextKeyboardButton.accessibilityLabel = "Next Keyboard"

        cancelButton.isHidden = true
        cancelButton.alpha = 1
        cancelButton.transform = .identity

        logoBarView.translatesAutoresizingMaskIntoConstraints = false

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
        
        // Add buttons as regular subviews to their respective fixed-size containers.
        // This prevents UIStackView from stretching them and keeps the logo centered.
        leadingControlsStack.addSubview(cancelButton)
        trailingControlsStack.addSubview(nextKeyboardButton)
        
        centerContainerView.addSubview(logoBarView)

        contentStack.addArrangedSubview(leadingControlsStack)
        contentStack.addArrangedSubview(centerContainerView)
        contentStack.addArrangedSubview(trailingControlsStack)

        mainStack.addArrangedSubview(contentStack)
        mainStack.addArrangedSubview(keyGridView)

        keyGridView.clipsToBounds = false
    }

    private func configureLayout() {
        cancelButtonWidthConstraint = cancelButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize)

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

            // Next Keyboard button centered on the right
            nextKeyboardButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            nextKeyboardButton.centerXAnchor.constraint(equalTo: trailingControlsStack.centerXAnchor),
            nextKeyboardButton.centerYAnchor.constraint(
                equalTo: trailingControlsStack.centerYAnchor,
                constant: Metrics.topRowSideControlVerticalOffset
            ),

            logoBarView.centerXAnchor.constraint(equalTo: centerContainerView.centerXAnchor),
            logoBarView.centerYAnchor.constraint(equalTo: centerContainerView.centerYAnchor),
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
