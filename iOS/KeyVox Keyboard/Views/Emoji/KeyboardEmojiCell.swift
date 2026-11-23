import UIKit

/// One emoji in the emoji page's grid, labeled for VoiceOver by the emoji itself, as on the
/// system keyboard.
final class KeyboardEmojiCell: UICollectionViewCell {
    static let reuseIdentifier = "KeyboardEmojiCell"

    private let glyphView = KeyboardEmojiGlyphView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        glyphView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glyphView)
        NSLayoutConstraint.activate([
            glyphView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glyphView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            glyphView.topAnchor.constraint(equalTo: contentView.topAnchor),
            glyphView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ emoji: String, font: UIFont) {
        glyphView.show(emoji, pointSize: font.pointSize)
        accessibilityLabel = emoji
    }
}
