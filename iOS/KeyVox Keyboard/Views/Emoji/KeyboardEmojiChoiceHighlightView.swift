import UIKit

/// The box under the chosen choice in the emoji pickers, one look for all of them: a white wash
/// over the panel, stronger in light mode so it shows over the lighter panel, and large enough
/// that it does not hug the emoji's edges.
final class KeyboardEmojiChoiceHighlightView: UIView {
    enum Measured {
        static let size: CGFloat = 43
        static let cornerRadius: CGFloat = 4.5
        static let darkWhite: CGFloat = 0.19
        static let lightWhite: CGFloat = 0.4
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        layer.cornerRadius = Measured.cornerRadius
        backgroundColor = UIColor { trait in
            UIColor.white.withAlphaComponent(trait.userInterfaceStyle == .dark ? Measured.darkWhite : Measured.lightWhite)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the box centered on `center`.
    func show(centeredAt center: CGPoint) {
        let half = Measured.size / 2
        frame = CGRect(x: center.x - half, y: center.y - half, width: Measured.size, height: Measured.size)
        isHidden = false
    }
}
