import KeyVoxPredictiveKeyboard
import UIKit

/// A held key's popup: its characters in their cells, the one the finger is on highlighted.
final class KeyboardHeldKeyPopupView: UIView {
    private let highlightView = UIView()
    /// One label per cell, kept for the next popup instead of being made again.
    private var labels: [UILabel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        highlightView.backgroundColor = KeyboardStyle.heldKeyPopupHighlightColor
        highlightView.layer.cornerRadius = KeyboardStyle.heldKeyPopupHighlightCornerRadius
        addSubview(highlightView)
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
        layer.cornerRadius = KeyboardStyle.heldKeyPopupCornerRadius
        layer.backgroundColor = KeyboardStyle.popupFillColor.resolvedColor(with: traitCollection).cgColor
        layer.borderColor = KeyboardStyle.popupBorderColor.resolvedColor(with: traitCollection).cgColor
        layer.borderWidth = KeyboardStyle.popupBorderWidth
        layer.shadowColor = KeyboardStyle.popupShadowColor.cgColor
        layer.shadowOpacity = KeyboardStyle.popupShadowOpacity
        layer.shadowRadius = KeyboardStyle.popupShadowRadius
        layer.shadowOffset = KeyboardStyle.popupShadowOffset
        // The fill is opaque, so the shadow takes the popup's rounded shape, given here to save
        // tracing it every frame.
        let cornerRadius = min(KeyboardStyle.heldKeyPopupCornerRadius, bounds.width / 2, bounds.height / 2)
        layer.shadowPath = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    }

    func present(_ layout: HeldKeyPopupLayout, in container: UIView) {
        frame = layout.frame
        if superview !== container {
            removeFromSuperview()
            container.addSubview(self)
        }
        let cells = layout.rows.flatMap { $0 }
        while labels.count < cells.count {
            let label = UILabel()
            label.textColor = KeyboardStyle.popupLabelColor
            label.textAlignment = .center
            labels.append(label)
            addSubview(label)
        }
        for (index, label) in labels.enumerated() {
            label.isHidden = index >= cells.count
            guard index < cells.count else { continue }
            // Each character is drawn as a key showing it would draw it, a little smaller.
            let keyFont = KeyboardKeyModel(kind: .character(cells[index].character), widthUnits: 1).titleFont
            label.font = keyFont.withSize(keyFont.pointSize * KeyboardStyle.heldKeyPopupFontScale)
            label.text = cells[index].character
            label.frame = convert(cells[index].frame, from: container)
        }
        select(layout.firstCell)
        isHidden = false
        setNeedsLayout()
    }

    func select(_ cell: HeldKeyPopupLayout.Cell) {
        guard let container = superview else { return }
        highlightView.frame = convert(cell.frame, from: container)
            .insetBy(dx: KeyboardStyle.heldKeyPopupHighlightInset, dy: 0)
    }

    /// Hides the popup, keeping it in place for the next held key instead of removing it.
    func dismiss() {
        isHidden = true
    }

    func refreshAppearance() {
        setNeedsLayout()
        layoutIfNeeded()
    }
}
