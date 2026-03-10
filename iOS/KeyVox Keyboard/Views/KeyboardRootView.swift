import UIKit

final class KeyboardRootView: UIView {

    let cancelButton = KeyboardCancelButton()
    let nextKeyboardButton = UIButton(type: .system)
    let logoBarView = KeyboardLogoBarView()
    let keyGridView = KeyboardKeyGridView()

    private let leadingControlsStack = UIView()
    private let trailingControlsStack = UIView()
    private let centerContainerView = UIView()
    private let contentStack = UIStackView()
    private let mainStack = UIStackView()

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

    func apply(state: KeyboardState, showsNextKeyboard: Bool, symbolPage: KeyboardSymbolPage) {
        let shouldShowCancel = state.showsCancelButton
        
        if shouldShowCancel && cancelButton.isHidden {
            // Animating in
            cancelButton.alpha = 0
            cancelButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            cancelButton.isHidden = false
            
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .allowUserInteraction, animations: {
                self.cancelButton.alpha = 1
                self.cancelButton.transform = .identity
            })
        } else if !shouldShowCancel && !cancelButton.isHidden {
            // Animating out
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .allowUserInteraction, animations: {
                self.cancelButton.alpha = 0
                self.cancelButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }) { _ in
                self.cancelButton.isHidden = true
                self.cancelButton.transform = .identity
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
        leadingControlsStack.addSubview(nextKeyboardButton)
        trailingControlsStack.addSubview(cancelButton)
        
        centerContainerView.addSubview(logoBarView)

        contentStack.addArrangedSubview(leadingControlsStack)
        contentStack.addArrangedSubview(centerContainerView)
        contentStack.addArrangedSubview(trailingControlsStack)

        mainStack.addArrangedSubview(contentStack)
        mainStack.addArrangedSubview(keyGridView)

        keyGridView.clipsToBounds = false
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            // Fixed width for both control containers ensures the logo stays perfectly centered
            // regardless of button visibility or individual button sizes.
            leadingControlsStack.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            trailingControlsStack.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            leadingControlsStack.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            trailingControlsStack.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),

            // Next Keyboard button centered on the left
            nextKeyboardButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            nextKeyboardButton.centerXAnchor.constraint(equalTo: leadingControlsStack.centerXAnchor),
            nextKeyboardButton.centerYAnchor.constraint(equalTo: leadingControlsStack.centerYAnchor),

            // Cancel button flush with the right edge of its container
            cancelButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize),
            cancelButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.cancelButtonSize),
            cancelButton.trailingAnchor.constraint(equalTo: trailingControlsStack.trailingAnchor),
            cancelButton.centerYAnchor.constraint(equalTo: trailingControlsStack.centerYAnchor),

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

#if DEBUG
    func debugLayoutSnapshot() -> String {
        func describe(_ view: UIView?) -> String {
            guard let view else { return "nil" }
            return "frame=\(NSCoder.string(for: view.frame)) bounds=\(NSCoder.string(for: view.bounds)) opaque=\(view.isOpaque) hidden=\(view.isHidden) alpha=\(String(format: "%.2f", view.alpha)) bg=\(String(describing: view.backgroundColor))"
        }

        return """
        root: \(describe(self))
        mainStack: \(describe(mainStack))
        contentStack: \(describe(contentStack))
        keyGridView: \(describe(keyGridView))
        """
    }
#endif
}
