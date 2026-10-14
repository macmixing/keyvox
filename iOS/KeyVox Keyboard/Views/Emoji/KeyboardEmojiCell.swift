import UIKit

/// One emoji in the emoji page's grid, labeled for VoiceOver by the emoji itself, as on the
/// system keyboard.
final class KeyboardEmojiCell: UICollectionViewCell {
    static let reuseIdentifier = "KeyboardEmojiCell"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ emoji: String, font: UIFont) {
        label.text = emoji
        label.font = font
        accessibilityLabel = emoji
    }
}
