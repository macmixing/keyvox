import UIKit

final class KeyboardRootView: UIView {
    let nextKeyboardButton = UIButton(type: .system)
    let micButton = UIButton(type: .system)
    let statusLabel = UILabel()

    private let contentStack = UIStackView()

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

    func apply(state: KeyboardState, showsNextKeyboard: Bool) {
        statusLabel.text = state.statusText
        nextKeyboardButton.isHidden = !showsNextKeyboard
        nextKeyboardButton.isEnabled = showsNextKeyboard

        micButton.isEnabled = state.isMicEnabled
        micButton.backgroundColor = state.micBackgroundColor
        micButton.alpha = state.isMicEnabled ? 1.0 : 0.8
        micButton.setImage(
            UIImage(systemName: state.micSymbolName, withConfiguration: KeyboardStyle.buttonSymbolConfiguration),
            for: .normal
        )
    }

    private func configureView() {
        backgroundColor = KeyboardStyle.backgroundColor
        layer.borderColor = KeyboardStyle.borderColor.cgColor
        layer.borderWidth = 1
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

        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.tintColor = .white
        micButton.layer.cornerRadius = KeyboardStyle.micButtonCornerRadius
        micButton.accessibilityLabel = "Record"

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = KeyboardStyle.statusFont
        statusLabel.textColor = KeyboardStyle.labelColor
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 1
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.distribution = .fill
        contentStack.spacing = KeyboardStyle.stackSpacing

        addSubview(contentStack)
        contentStack.addArrangedSubview(nextKeyboardButton)
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(micButton)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: KeyboardStyle.minHeight),

            nextKeyboardButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),

            micButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.micButtonSize),
            micButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.micButtonSize),

            contentStack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: KeyboardStyle.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -KeyboardStyle.horizontalPadding),
            contentStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            contentStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),
        ])
    }
}
