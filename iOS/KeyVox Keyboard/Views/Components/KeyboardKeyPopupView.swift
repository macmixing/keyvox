import UIKit

final class KeyboardKeyPopupView: UIView {
    private let titleLabel = UILabel()
    private var presentedAt: TimeInterval?
    private var presentationGeneration = 0
    private var pendingDismissWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        alpha = 0
        observeBorderAppearanceChanges()

        let contentInsets = KeyboardStyle.popupContentInsets

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = KeyboardStyle.popupFont
        titleLabel.textColor = KeyboardStyle.popupLabelColor
        titleLabel.textAlignment = .center
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: contentInsets.left),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -contentInsets.right),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: contentInsets.top),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -contentInsets.bottom),
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
        pendingDismissWorkItem?.cancel()
        pendingDismissWorkItem = nil
        presentationGeneration += 1
        titleLabel.attributedText = keyView.model.attributedTitle(for: text)

        let keyFrame = keyView.convert(keyView.bounds, to: container)
        let contentInsets = KeyboardStyle.popupContentInsets
        let labelSize = titleLabel.sizeThatFits(
            CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        let popupSize = CGSize(
            width: max(
                keyFrame.width * KeyboardStyle.popupWidthMultiplier,
                labelSize.width + contentInsets.left + contentInsets.right
            ),
            height: max(
                keyFrame.height * KeyboardStyle.popupHeightMultiplier,
                labelSize.height + contentInsets.top + contentInsets.bottom
            )
        )
        let popupY = max(0, keyFrame.minY - popupSize.height - 2)
        let minX = KeyboardStyle.popupMinEdgeInset
        let maxX = max(minX, container.bounds.width - popupSize.width - KeyboardStyle.popupMinEdgeInset)
        let popupFrame = CGRect(
            x: min(max(minX, keyFrame.midX - popupSize.width / 2), maxX),
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
        presentedAt = ProcessInfo.processInfo.systemUptime
    }

    func dismiss() {
        guard superview != nil else { return }
        pendingDismissWorkItem?.cancel()
        pendingDismissWorkItem = nil

        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = presentedAt.map { now - $0 } ?? KeyboardStyle.popupMinimumVisibleDuration
        let remaining = KeyboardStyle.popupMinimumVisibleDuration - elapsed
        let generation = presentationGeneration
        guard remaining > 0 else {
            removeFromSuperviewIfCurrent(generation: generation)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.removeFromSuperviewIfCurrent(generation: generation)
        }
        pendingDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
    }

    private func removeFromSuperviewIfCurrent(generation: Int) {
        guard generation == presentationGeneration else { return }
        pendingDismissWorkItem = nil
        presentedAt = nil
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
