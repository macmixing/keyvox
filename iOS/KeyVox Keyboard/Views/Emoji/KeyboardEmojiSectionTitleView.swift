import UIKit

/// The title above one of the emoji page's sections, in the system keyboard's small gray capitals.
final class KeyboardEmojiSectionTitleView: UICollectionReusableView {
    /// Matched to the system keyboard's screenshot: its "SMILEYS & PEOPLE" is 115 points wide.
    private static let font = UIFont.systemFont(ofSize: 12.3, weight: .semibold)

    static let kind = "KeyboardEmojiSectionTitle"
    static let reuseIdentifier = "KeyboardEmojiSectionTitleView"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Self.font
        label.textColor = .secondaryLabel
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// How wide `title` is drawn.
    static func width(of title: String) -> CGFloat {
        ceil((title as NSString).size(withAttributes: [.font: font]).width)
    }

    func show(_ title: String) {
        label.text = title
    }
}
