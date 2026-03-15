import UIKit

final class KeyboardKeyPopupView: UIView {
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        alpha = 0
        observeBorderAppearanceChanges()

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

    private func observeBorderAppearanceChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let resolvedFillColor = KeyboardStyle.popupFillColor.resolvedColor(with: traitCollection)
        let resolvedBorderColor = KeyboardStyle.popupBorderColor.resolvedColor(with: traitCollection)

        layer.cornerRadius = KeyboardStyle.popupCornerRadius
        layer.backgroundColor = resolvedFillColor.cgColor
        layer.borderColor = resolvedBorderColor.cgColor
        layer.borderWidth = KeyboardStyle.popupBorderWidth

        layer.shadowColor = KeyboardStyle.popupShadowColor.cgColor
        layer.shadowOpacity = KeyboardStyle.popupShadowOpacity
        layer.shadowRadius = KeyboardStyle.popupShadowRadius
        layer.shadowOffset = KeyboardStyle.popupShadowOffset
    }

    func present(text: String, from keyView: KeyboardKeyView, in container: UIView) {
        titleLabel.text = text

        let keyFrame = keyView.convert(keyView.bounds, to: container)
        let popupSize = CGSize(
            width: keyFrame.width * KeyboardStyle.popupWidthMultiplier,
            height: keyFrame.height * KeyboardStyle.popupHeightMultiplier
        )
        let popupY = max(0, keyFrame.minY - popupSize.height - 2)
        let popupFrame = CGRect(
            x: keyFrame.midX - popupSize.width / 2,
            y: popupY,
            width: popupSize.width,
            height: popupSize.height
        )
        frame = pixelAlignedFrame(for: popupFrame)

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

    private func pixelAlignedFrame(for rect: CGRect) -> CGRect {
        let scale = window?.screen.scale ?? UIScreen.main.scale
        let safeScale = max(scale, 1)

        return CGRect(
            x: (rect.origin.x * safeScale).rounded() / safeScale,
            y: (rect.origin.y * safeScale).rounded() / safeScale,
            width: (rect.size.width * safeScale).rounded() / safeScale,
            height: (rect.size.height * safeScale).rounded() / safeScale
        )
    }

    func refreshAppearance() {
        setNeedsLayout()
        layoutIfNeeded()
    }

}
