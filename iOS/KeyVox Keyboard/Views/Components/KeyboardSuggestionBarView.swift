import KeyVoxPredictiveKeyboard
import UIKit

/// The three suggestion slots shown above the letter keys: leading, primary (center),
/// and trailing. The autocorrection space will apply is shown in a heavier weight.
final class KeyboardSuggestionBarView: UIView {
    var onItemSelected: ((SuggestionBar.Item) -> Void)?

    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var items: [SuggestionBar.Item?] = [nil, nil, nil]

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = KeyboardStyle.keySpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        for index in 0..<3 {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
            configuration.titleLineBreakMode = .byTruncatingTail
            let button = UIButton(configuration: configuration)
            button.tag = index
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            button.layer.cornerRadius = KeyboardStyle.keyCornerRadius
            button.layer.borderWidth = KeyboardStyle.keyBorderWidth
            button.configurationUpdateHandler = { [weak self] button in
                self?.applyAppearance(to: button)
            }
            stackView.addArrangedSubview(button)
            buttons.append(button)
        }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.refreshAppearance()
        }
        refreshAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ bar: SuggestionBar) {
        let newItems = [bar.leading, bar.primary, bar.trailing]
        guard newItems != items else { return }
        items = newItems
        for (button, item) in zip(buttons, items) {
            var configuration = button.configuration
            configuration?.attributedTitle = item.map { item in
                AttributedString(
                    item.text,
                    attributes: AttributeContainer([
                        .font: UIFont.systemFont(
                            ofSize: 16,
                            weight: item.kind == .autocorrection ? .bold : .medium
                        ),
                    ])
                )
            }
            button.configuration = configuration
            button.isEnabled = item != nil
            button.accessibilityLabel = item?.text
        }
        refreshAppearance()
    }

    private func refreshAppearance() {
        buttons.forEach(applyAppearance)
    }

    /// Gives a suggestion the keys' colors, and the keys' pressed colors while it is touched.
    private func applyAppearance(to button: UIButton) {
        guard items.indices.contains(button.tag), items[button.tag] != nil else {
            button.configuration?.baseForegroundColor = .clear
            button.backgroundColor = .clear
            button.layer.borderColor = UIColor.clear.cgColor
            return
        }
        let isPressed = button.isHighlighted
        button.configuration?.baseForegroundColor = KeyboardStyle.keyLabelColor
        button.backgroundColor = (isPressed ? KeyboardStyle.keyPressedFillColor : KeyboardStyle.keyFillColor)
            .withAlphaComponent(0.3)
        button.layer.borderColor = (isPressed ? KeyboardStyle.keyPressedBorderColor : KeyboardStyle.keyBorderColor)
            .resolvedColor(with: traitCollection)
            .cgColor
    }

    @objc
    private func handleTap(_ sender: UIButton) {
        guard items.indices.contains(sender.tag), let item = items[sender.tag] else { return }
        onItemSelected?(item)
    }
}
