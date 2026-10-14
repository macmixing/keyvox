import KeyVoxEmoji
import UIKit

/// The bar under the emoji page's grid, as on the system emoji keyboard: the key back to the
/// letters, a button for each category with the one showing circled, and delete.
final class KeyboardEmojiCategoryBar: UIView {
    /// The system emoji keyboard's bar on a 402-point-wide iPhone, in points, measured with
    /// Tools/AppleKeyboardBaseline (`EmojiKeyboardProbeTests`).
    enum Measured {
        static let height: CGFloat = 40
        static let lettersKeyWidth: CGFloat = 50.3
        static let deleteKeyWidth: CGFloat = 49.3
    }

    /// Matched to the system keyboard's screenshot from the same measurement: its category
    /// pictures are drawn about 19 points tall, inside a circle about 30 points across, and its
    /// letters key's label about 28 points wide.
    enum Drawn {
        static let symbolPointSize: CGFloat = 16
        static let selectionDiameter: CGFloat = 30
        static let lettersKeyFontSize: CGFloat = 15
    }

    var onLetters: (() -> Void)?
    var onCategory: ((EmojiKeyboardCategory) -> Void)?
    var onDeleteBegan: (() -> Void)?
    var onDeleteEnded: (() -> Void)?

    private let lettersButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let categoryStack = UIStackView()
    private var categoryButtons: [(category: EmojiKeyboardCategory, button: UIButton)] = []
    private let selectionView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        lettersButton.setTitle("ABC", for: .normal)
        lettersButton.titleLabel?.font = .systemFont(ofSize: Drawn.lettersKeyFontSize)
        lettersButton.setTitleColor(.label, for: .normal)
        lettersButton.accessibilityLabel = KeyboardKeyModel(kind: .abc, widthUnits: 1).accessibilityLabel
        lettersButton.addTarget(self, action: #selector(handleLetters), for: .touchUpInside)

        deleteButton.setImage(Self.symbol("delete.left"), for: .normal)
        deleteButton.tintColor = .label
        deleteButton.accessibilityLabel = KeyboardKeyModel(kind: .delete, widthUnits: 1).accessibilityLabel
        deleteButton.addTarget(self, action: #selector(handleDeleteBegan), for: .touchDown)
        deleteButton.addTarget(self, action: #selector(handleDeleteEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        categoryStack.axis = .horizontal
        categoryStack.distribution = .fillEqually
        categoryStack.alignment = .fill

        selectionView.backgroundColor = .tertiarySystemFill
        selectionView.layer.cornerRadius = Drawn.selectionDiameter / 2
        selectionView.isUserInteractionEnabled = false
        selectionView.isHidden = true

        for view in [lettersButton, categoryStack, deleteButton] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        insertSubview(selectionView, belowSubview: categoryStack)
        NSLayoutConstraint.activate([
            lettersButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            lettersButton.topAnchor.constraint(equalTo: topAnchor),
            lettersButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            lettersButton.widthAnchor.constraint(equalToConstant: Measured.lettersKeyWidth),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            deleteButton.topAnchor.constraint(equalTo: topAnchor),
            deleteButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: Measured.deleteKeyWidth),
            categoryStack.leadingAnchor.constraint(equalTo: lettersButton.trailingAnchor),
            categoryStack.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor),
            categoryStack.topAnchor.constraint(equalTo: topAnchor),
            categoryStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCategories(_ categories: [EmojiKeyboardCategory]) {
        guard categories != categoryButtons.map(\.category) else { return }
        categoryButtons.forEach { $0.button.removeFromSuperview() }
        categoryButtons = categories.map { category in
            let button = UIButton(type: .system)
            button.setImage(Self.symbol(category.symbolName), for: .normal)
            button.tintColor = .secondaryLabel
            button.accessibilityLabel = category.accessibilityLabel
            button.addAction(UIAction { [weak self] _ in self?.onCategory?(category) }, for: .touchUpInside)
            categoryStack.addArrangedSubview(button)
            return (category, button)
        }
    }

    /// Circles `category`'s button, or none.
    func select(_ category: EmojiKeyboardCategory?) {
        guard let button = categoryButtons.first(where: { $0.category == category })?.button else {
            selectionView.isHidden = true
            return
        }
        layoutIfNeeded()
        let center = categoryStack.convert(button.center, to: self)
        selectionView.frame = CGRect(
            x: center.x - (Drawn.selectionDiameter / 2),
            y: center.y - (Drawn.selectionDiameter / 2),
            width: Drawn.selectionDiameter,
            height: Drawn.selectionDiameter
        )
        selectionView.isHidden = false
        for (other, otherButton) in categoryButtons {
            otherButton.accessibilityTraits = other == category ? [.button, .selected] : .button
        }
    }

    @objc private func handleLetters() {
        onLetters?()
    }

    @objc private func handleDeleteBegan() {
        onDeleteBegan?()
    }

    @objc private func handleDeleteEnded() {
        onDeleteEnded?()
    }

    private static func symbol(_ name: String) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: Drawn.symbolPointSize))
    }
}
