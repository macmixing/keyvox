import UIKit

final class KeyboardRootView: UIView {
    let cancelButton = UIButton(type: .system)
    let nextKeyboardButton = UIButton(type: .system)
    let logoBarView = KeyboardLogoBarView()
    let keyGridView = KeyboardKeyGridView()

    private let leadingControlsStack = UIStackView()
    private let centerContainerView = UIView()
    private let trailingSpacerView = UIView()
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
        cancelButton.isHidden = !state.showsCancelButton
        cancelButton.isEnabled = state.showsCancelButton
        nextKeyboardButton.isHidden = !showsNextKeyboard
        nextKeyboardButton.isEnabled = showsNextKeyboard

        logoBarView.visualState = state.logoVisualState
        logoBarView.isEnabled = state.isLogoBarEnabled

        keyGridView.setSymbolPage(symbolPage)
        keyGridView.setKeyboardEnabled(true)
    }

    private func configureView() {
        backgroundColor = .clear
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureSubviews() {
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.tintColor = KeyboardStyle.labelColor
        cancelButton.backgroundColor = KeyboardStyle.buttonFillColor
        cancelButton.layer.cornerRadius = KeyboardStyle.buttonCornerRadius
        cancelButton.setImage(
            UIImage(systemName: "xmark", withConfiguration: KeyboardStyle.buttonSymbolConfiguration),
            for: .normal
        )
        cancelButton.accessibilityLabel = "Cancel"

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
        trailingSpacerView.translatesAutoresizingMaskIntoConstraints = false

        leadingControlsStack.translatesAutoresizingMaskIntoConstraints = false
        leadingControlsStack.axis = .horizontal
        leadingControlsStack.alignment = .center
        leadingControlsStack.distribution = .fill
        leadingControlsStack.spacing = KeyboardStyle.stackSpacing
        leadingControlsStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        leadingControlsStack.setContentHuggingPriority(.required, for: .horizontal)

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
        mainStack.clipsToBounds = true

        addSubview(mainStack)
        leadingControlsStack.addArrangedSubview(cancelButton)
        leadingControlsStack.addArrangedSubview(nextKeyboardButton)
        centerContainerView.addSubview(logoBarView)

        contentStack.addArrangedSubview(leadingControlsStack)
        contentStack.addArrangedSubview(centerContainerView)
        contentStack.addArrangedSubview(trailingSpacerView)

        mainStack.addArrangedSubview(contentStack)
        mainStack.addArrangedSubview(keyGridView)

        keyGridView.clipsToBounds = false
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            cancelButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            cancelButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),

            nextKeyboardButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),

            logoBarView.widthAnchor.constraint(equalToConstant: KeyboardStyle.logoBarSize),
            logoBarView.heightAnchor.constraint(equalToConstant: KeyboardStyle.logoBarSize),
            logoBarView.centerXAnchor.constraint(equalTo: centerContainerView.centerXAnchor),
            logoBarView.centerYAnchor.constraint(equalTo: centerContainerView.centerYAnchor),
            centerContainerView.heightAnchor.constraint(greaterThanOrEqualTo: logoBarView.heightAnchor),

            trailingSpacerView.widthAnchor.constraint(equalTo: leadingControlsStack.widthAnchor),
            trailingSpacerView.heightAnchor.constraint(equalTo: leadingControlsStack.heightAnchor),

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
