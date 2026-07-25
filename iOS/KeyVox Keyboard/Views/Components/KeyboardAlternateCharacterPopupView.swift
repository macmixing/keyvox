import UIKit

final class KeyboardAlternateCharacterPopupView: UIView {
    private let stackView = UIStackView()
    private var labels: [UILabel] = []
    private var values: [String] = []
    private var selectedIndex: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = KeyboardStyle.popupCornerRadius
        layer.backgroundColor = KeyboardStyle.popupFillColor
            .resolvedColor(with: traitCollection)
            .cgColor
        layer.borderColor = KeyboardStyle.popupBorderColor
            .resolvedColor(with: traitCollection)
            .cgColor
        layer.borderWidth = KeyboardStyle.popupBorderWidth
        layer.shadowColor = KeyboardStyle.popupShadowColor.cgColor
        layer.shadowOpacity = KeyboardStyle.popupShadowOpacity
        layer.shadowRadius = KeyboardStyle.popupShadowRadius
        layer.shadowOffset = KeyboardStyle.popupShadowOffset
    }

    func present(
        alternates: [String],
        primaryValue: String,
        from keyView: KeyboardKeyView,
        in container: UIView
    ) {
        guard alternates.isEmpty == false else { return }

        let keyFrame = keyView.convert(keyView.bounds, to: container)
        let itemWidth = max(38, keyFrame.width)
        let itemCount = alternates.count + 1
        let availableWidth = max(
            1,
            container.bounds.width - KeyboardStyle.popupMinEdgeInset * 2
        )
        let popupWidth = min(
            itemWidth * CGFloat(itemCount) + 8,
            availableWidth
        )
        let popupHeight = max(52, keyFrame.height + 8)
        let preferredX = keyFrame.midX - popupWidth / 2
        let minimumX = KeyboardStyle.popupMinEdgeInset
        let maximumX = max(
            minimumX,
            container.bounds.width - popupWidth - KeyboardStyle.popupMinEdgeInset
        )
        frame = CGRect(
            x: min(max(minimumX, preferredX), maximumX),
            y: max(0, keyFrame.minY - popupHeight - 4),
            width: popupWidth,
            height: popupHeight
        )

        let visibleItemWidth = max(1, (popupWidth - 8) / CGFloat(itemCount))
        let primaryIndex = min(
            max(0, Int((keyFrame.midX - frame.minX - 4) / visibleItemWidth)),
            itemCount - 1
        )
        values = alternates
        values.insert(primaryValue, at: primaryIndex)
        selectedIndex = primaryIndex
        rebuildLabels(values: values)

        if superview !== container {
            removeFromSuperview()
            container.addSubview(self)
        }
        refreshLabelAppearance()
        setNeedsLayout()
        layoutIfNeeded()
    }

    func updateSelection(at point: CGPoint, in container: UIView) {
        guard superview === container, values.isEmpty == false else { return }
        let localPoint = container.convert(point, to: self)
        let contentWidth = max(1, bounds.width - 8)
        let itemWidth = contentWidth / CGFloat(values.count)
        let rawIndex = Int((localPoint.x - 4) / itemWidth)
        selectedIndex = min(max(0, rawIndex), values.count - 1)
        refreshLabelAppearance()
    }

    func selectedValue() -> String? {
        guard let selectedIndex, values.indices.contains(selectedIndex) else { return nil }
        return values[selectedIndex]
    }

    func dismiss() {
        removeFromSuperview()
        values = []
        selectedIndex = nil
    }

    private func rebuildLabels(values: [String]) {
        labels.forEach { label in
            stackView.removeArrangedSubview(label)
            label.removeFromSuperview()
        }
        labels = values.map { value in
            let label = UILabel()
            label.text = value
            label.font = UIFont.systemFont(ofSize: 22, weight: .medium)
            label.textAlignment = .center
            label.layer.cornerRadius = 7
            label.layer.masksToBounds = true
            stackView.addArrangedSubview(label)
            return label
        }
    }

    private func refreshLabelAppearance() {
        for (index, label) in labels.enumerated() {
            let isSelected = index == selectedIndex
            label.backgroundColor = isSelected
                ? KeyboardStyle.specialKeyPressedFillColor
                : .clear
            label.textColor = isSelected ? .white : KeyboardStyle.popupLabelColor
        }
    }
}
