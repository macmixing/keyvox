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
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 12).cgPath
        shapeLayer.fillColor = KeyboardStyle.popupFillColor.cgColor
        shapeLayer.strokeColor = UIColor.separator.withAlphaComponent(0.15).cgColor
        shapeLayer.lineWidth = 0.5
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    func present(text: String, from keyView: KeyboardKeyView, in container: UIView) {
        popupText = text
        titleLabel.text = text

        let keyFrame = keyView.convert(keyView.bounds, to: container)
        let popupSize = CGSize(width: keyFrame.width * 1.25, height: keyFrame.height * 1.35)
        let popupY = max(0, keyFrame.minY - popupSize.height - 2)
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

        alpha = 1
        transform = .identity
    }

    func dismiss() {
        guard superview != nil else { return }
        removeFromSuperview()
    }

}
