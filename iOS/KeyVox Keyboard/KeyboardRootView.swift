import UIKit

final class KeyboardRootView: UIView {
    let cancelButton = UIButton(type: .system)
    let nextKeyboardButton = UIButton(type: .system)
    let micButton = UIButton(type: .system)
    let statusLabel = UILabel()

    private let leadingControlsStack = UIStackView()
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
        cancelButton.isHidden = !state.showsCancelButton
        cancelButton.isEnabled = state.showsCancelButton
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

        leadingControlsStack.translatesAutoresizingMaskIntoConstraints = false
        leadingControlsStack.axis = .horizontal
        leadingControlsStack.alignment = .center
        leadingControlsStack.distribution = .fill
        leadingControlsStack.spacing = KeyboardStyle.stackSpacing

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.distribution = .fill
        contentStack.spacing = KeyboardStyle.stackSpacing

        addSubview(contentStack)
        leadingControlsStack.addArrangedSubview(cancelButton)
        leadingControlsStack.addArrangedSubview(nextKeyboardButton)

        contentStack.addArrangedSubview(leadingControlsStack)
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(micButton)
    }

    private func configureLayout() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: KeyboardStyle.minHeight),

            cancelButton.widthAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),
            cancelButton.heightAnchor.constraint(equalToConstant: KeyboardStyle.buttonSize),

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
