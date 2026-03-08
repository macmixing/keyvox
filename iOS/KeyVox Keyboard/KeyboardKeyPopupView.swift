import UIKit

final class KeyboardKeyPopupView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let titleLabel = UILabel()
    private var popupText: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        alpha = 0
        layer.addSublayer(shapeLayer)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = KeyboardStyle.popupFont
        titleLabel.textColor = KeyboardStyle.popupLabelColor
        titleLabel.textAlignment = .center
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.path = popupPath(in: bounds).cgPath
        shapeLayer.fillColor = KeyboardStyle.popupFillColor.cgColor
        shapeLayer.strokeColor = KeyboardStyle.popupBorderColor.cgColor
        shapeLayer.lineWidth = 0.5
        layer.shadowColor = KeyboardStyle.popupShadow.color.cgColor
        layer.shadowOpacity = KeyboardStyle.popupShadow.opacity
        layer.shadowRadius = KeyboardStyle.popupShadow.radius
        layer.shadowOffset = KeyboardStyle.popupShadow.offset
    }

    func present(text: String, from keyView: KeyboardKeyView, in container: UIView) {
        popupText = text
        titleLabel.text = text

        let keyFrame = keyView.convert(keyView.bounds, to: container)
        let popupSize = CGSize(width: max(54, keyFrame.width * 1.28), height: 84)
        let popupY = max(4, keyFrame.minY - popupSize.height + 20)
        frame = CGRect(
            x: keyFrame.midX - popupSize.width / 2,
            y: popupY,
            width: popupSize.width,
            height: popupSize.height
        )

        if superview !== container {
            removeFromSuperview()
            container.addSubview(self)
        }

        setNeedsLayout()
        layoutIfNeeded()

        transform = CGAffineTransform(scaleX: 0.84, y: 0.84).translatedBy(x: 0, y: 6)
        alpha = 0
        UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func dismiss() {
        guard superview != nil else { return }
        UIView.animate(withDuration: 0.06, delay: 0, options: [.beginFromCurrentState, .curveEaseIn]) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9).translatedBy(x: 0, y: 4)
        } completion: { _ in
            self.removeFromSuperview()
            self.transform = .identity
        }
    }

    private func popupPath(in rect: CGRect) -> UIBezierPath {
        let bubbleHeight = rect.height - 24
        let bubbleRect = CGRect(x: 0, y: 0, width: rect.width, height: bubbleHeight)
        let stemWidth = min(KeyboardStyle.popupStemWidth, rect.width - 20)
        let stemHeight = KeyboardStyle.popupStemHeight
        let stemRect = CGRect(
            x: (rect.width - stemWidth) / 2,
            y: bubbleHeight - 10,
            width: stemWidth,
            height: stemHeight + 10
        )

        let path = UIBezierPath(roundedRect: bubbleRect, cornerRadius: KeyboardStyle.popupCornerRadius)
        path.append(UIBezierPath(roundedRect: stemRect, cornerRadius: KeyboardStyle.popupStemCornerRadius))
        return path
    }
}
