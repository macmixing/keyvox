import UIKit

final class KeyboardPredictionBarView: UIView {
    var onChoiceSelected: ((KeyboardPredictionChoice) -> Void)?

    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var slotChoices: [KeyboardPredictionChoice?] = [nil, nil, nil]

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
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: 4,
                leading: 6,
                bottom: 4,
                trailing: 6
            )
            let button = UIButton(configuration: configuration)
            button.tag = index
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.addTarget(self, action: #selector(handleChoiceTap(_:)), for: .touchUpInside)
            button.layer.cornerRadius = KeyboardStyle.keyCornerRadius
            button.layer.borderWidth = KeyboardStyle.keyBorderWidth
            stackView.addArrangedSubview(button)
            buttons.append(button)
        }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        refreshAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(choices: [KeyboardPredictionChoice]) {
        let visibleChoices = Array(choices.prefix(buttons.count))
        if visibleChoices.count == 1, visibleChoices[0].kind == .literal {
            slotChoices = [nil, visibleChoices[0], nil]
        } else {
            slotChoices = (0..<buttons.count).map { index in
                visibleChoices.indices.contains(index) ? visibleChoices[index] : nil
            }
        }
        for (index, button) in buttons.enumerated() {
            guard let choice = slotChoices[index] else {
                button.configuration?.title = nil
                button.isEnabled = false
                button.isHidden = false
                button.accessibilityLabel = nil
                button.accessibilityHint = nil
                continue
            }
            button.configuration?.title = choice.text
            button.isEnabled = true
            button.isHidden = false
            button.accessibilityLabel = choice.text
            button.accessibilityHint = accessibilityHint(for: choice.kind)
        }
        refreshAppearance()
    }

    func refreshAppearance() {
        for (index, button) in buttons.enumerated() {
            guard let choice = slotChoices[index] else {
                button.configuration?.baseForegroundColor = .clear
                button.backgroundColor = .clear
                button.layer.borderColor = UIColor.clear.cgColor
                continue
            }
            let isLiteral = choice.kind == .literal
            button.configuration?.baseForegroundColor = KeyboardStyle.keyLabelColor
            button.backgroundColor = isLiteral
                ? KeyboardStyle.keyFillColor.withAlphaComponent(0.72)
                : KeyboardStyle.specialKeyFillColor.withAlphaComponent(0.72)
            button.layer.borderColor = KeyboardStyle.keyBorderColor
                .resolvedColor(with: traitCollection)
                .cgColor
        }
    }

    @objc
    private func handleChoiceTap(_ sender: UIButton) {
        guard slotChoices.indices.contains(sender.tag),
              let choice = slotChoices[sender.tag] else { return }
        onChoiceSelected?(choice)
    }

    private func accessibilityHint(for kind: KeyboardPredictionChoice.Kind) -> String {
        switch kind {
        case .literal:
            return "Keep typed word"
        case .correction:
            return "Use correction"
        case .completion:
            return "Complete word"
        case .nextWord:
            return "Insert next word"
        case .accent:
            return "Use accented spelling"
        }
    }
}
