import KeyVoxPredictiveKeyboard
import UIKit

/// The three suggestion slots shown above the letter keys: leading, primary (center),
/// and trailing. The autocorrection space will apply is shown in a heavier weight. The trailing
/// slot splits evenly among the bar's first emoji when it has any, as on the system keyboard. An
/// emoji that would blend into its key gets a soft glow so it stays easy to see. A rescued
/// dictation shows as one suggestion across the whole bar in their place. While the space bar is a
/// trackpad, the suggestions go blank as the keys do.
final class KeyboardSuggestionBarView: UIView {
    var onItemSelected: ((SuggestionBar.Item) -> Void)?
    /// Called when the rescued dictation is tapped.
    var onRescuedDictationSelected: (() -> Void)?
    /// Called when a suggestion is pressed and held, instead of selecting it.
    var onItemLongPressed: ((SuggestionBar.Item) -> Void)?

    var isTrackpadModeActive = false {
        didSet {
            guard isTrackpadModeActive != oldValue else { return }
            emojiGlyphViews.forEach { $0.alpha = isTrackpadModeActive ? 0 : 1 }
            buttons.forEach(applyAppearance)
            applyKeyAppearance(to: rescuedDictationButton, isShown: true)
        }
    }

    /// The most emoji the trailing slot holds, as on the system keyboard; with the bar running to the
    /// keyboard's edge, they fit drawn without side insets.
    private static let emojiSlots = 3
    /// How far an emoji's glow spreads around it, in points, and how strongly it shows.
    private static let emojiGlowRadius: CGFloat = 3
    private static let emojiGlowOpacity: CGFloat = 0.9
    /// The size of the bar's words, and the size its emoji are drawn at.
    private static let textPointSize: CGFloat = 16

    private let stackView = UIStackView()
    private let trailingSlot = UIStackView()
    private let rescuedDictationButton = UIButton(configuration: .plain())
    /// The leading, primary, and trailing buttons, then the trailing slot's emoji buttons.
    private var buttons: [UIButton] = []
    /// The trailing slot's emoji, drawn by the shared emoji renderer, one per emoji button.
    private var emojiGlyphViews: [KeyboardEmojiGlyphView] = []
    private var items: [SuggestionBar.Item?] = Array(repeating: nil, count: 3 + emojiSlots)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        for stack in [stackView, trailingSlot] {
            stack.axis = .horizontal
            stack.alignment = .fill
            stack.distribution = .fillEqually
            stack.spacing = KeyboardStyle.keySpacing
        }
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        for index in 0..<(3 + Self.emojiSlots) {
            var configuration = UIButton.Configuration.plain()
            let sideInset: CGFloat = index < 3 ? 6 : 0
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: sideInset, bottom: 4, trailing: sideInset)
            configuration.titleLineBreakMode = .byTruncatingTail
            let button = UIButton(configuration: configuration)
            button.tag = index
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            // Recognizing the hold cancels the button's touch, so a held suggestion is not
            // also selected.
            button.addGestureRecognizer(UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleLongPress(_:))
            ))
            button.layer.cornerRadius = KeyboardStyle.keyCornerRadius
            button.layer.borderWidth = KeyboardStyle.keyBorderWidth
            button.configurationUpdateHandler = { [weak self] button in
                self?.applyAppearance(to: button)
            }
            if index >= 3 {
                let glyphView = KeyboardEmojiGlyphView()
                glyphView.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(glyphView)
                NSLayoutConstraint.activate([
                    glyphView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                    glyphView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                    glyphView.topAnchor.constraint(equalTo: button.topAnchor),
                    glyphView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                ])
                emojiGlyphViews.append(glyphView)
            }
            if index < 2 {
                stackView.addArrangedSubview(button)
            } else {
                trailingSlot.addArrangedSubview(button)
                button.isHidden = index > 2
            }
            buttons.append(button)
        }
        stackView.addArrangedSubview(trailingSlot)

        var rescuedConfiguration = UIButton.Configuration.plain()
        rescuedConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        rescuedConfiguration.titleLineBreakMode = .byTruncatingTail
        rescuedDictationButton.configuration = rescuedConfiguration
        rescuedDictationButton.translatesAutoresizingMaskIntoConstraints = false
        rescuedDictationButton.isHidden = true
        rescuedDictationButton.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        rescuedDictationButton.layer.borderWidth = KeyboardStyle.keyBorderWidth
        rescuedDictationButton.addTarget(self, action: #selector(handleRescuedDictationTap), for: .touchUpInside)
        rescuedDictationButton.configurationUpdateHandler = { [weak self] button in
            self?.applyKeyAppearance(to: button, isShown: true)
        }
        addSubview(rescuedDictationButton)

        NSLayoutConstraint.activate([
            rescuedDictationButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            rescuedDictationButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            rescuedDictationButton.topAnchor.constraint(equalTo: topAnchor),
            rescuedDictationButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        registerForTraitChanges([UITraitUserInterfaceStyle.self, KeyboardThemeTrait.self]) { (self: Self, _: UITraitCollection) in
            self.refreshAppearance()
        }
        refreshAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ bar: SuggestionBar) {
        let emoji = bar.emoji.prefix(Self.emojiSlots)
        let newItems = [bar.leading, bar.primary, bar.trailing]
            + (0..<Self.emojiSlots).map { emoji.indices.contains($0) ? emoji[$0] : nil }
        guard newItems != items else { return }
        let oldItems = items
        items = newItems
        // The trailing slot shows its word, or as many emoji buttons as there are emoji.
        buttons[2].isHidden = emoji.isEmpty == false
        for slot in 0..<Self.emojiSlots {
            buttons[3 + slot].isHidden = slot >= emoji.count
        }
        // Restyling a button lays it out again, so only slots whose suggestion changed are
        // restyled; the others already show their suggestion in its colors.
        for (index, button) in buttons.enumerated() where newItems[index] != oldItems[index] {
            let item = newItems[index]
            applyTitle(to: button)
            button.isEnabled = item != nil
            button.accessibilityLabel = item?.text
            applyAppearance(to: button)
        }
    }

    /// Shows `text` as one suggestion across the bar, or the bar's own suggestions when nil.
    func showRescuedDictation(_ text: String?) {
        stackView.isHidden = text != nil
        rescuedDictationButton.isHidden = text == nil
        guard let text else { return }
        let singleLine = text.components(separatedBy: .newlines).joined(separator: " ")
        rescuedDictationButton.configuration?.attributedTitle = AttributedString(
            singleLine,
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: Self.textPointSize, weight: .medium)])
        )
        rescuedDictationButton.accessibilityLabel = text
        applyKeyAppearance(to: rescuedDictationButton, isShown: true)
    }

    private func refreshAppearance() {
        // Whether an emoji needs its glow depends on the keys' colors, so the emoji are titled
        // again for the new colors.
        buttons.dropFirst(3).forEach(applyTitle)
        buttons.forEach(applyAppearance)
        applyKeyAppearance(to: rescuedDictationButton, isShown: true)
    }

    /// Titles a suggestion with its text, and gives an emoji that would blend into its key a soft
    /// glow in the keys' label color so it stands apart from the key.
    private func applyTitle(to button: UIButton) {
        let item = items.indices.contains(button.tag) ? items[button.tag] : nil
        if button.tag >= 3 {
            applyEmoji(item, to: emojiGlyphViews[button.tag - 3])
            return
        }
        var configuration = button.configuration
        configuration?.attributedTitle = item.map { item in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(
                    ofSize: Self.textPointSize,
                    weight: item.kind == .autocorrection ? .bold : .medium
                ),
            ]
            return AttributedString(item.text, attributes: AttributeContainer(attributes))
        }
        button.configuration = configuration
    }

    /// Shows an emoji in its slot, with a soft halo in the keys' label color when it would blend
    /// into its key, so it stands apart from the key.
    private func applyEmoji(_ item: SuggestionBar.Item?, to glyphView: KeyboardEmojiGlyphView) {
        glyphView.show(item?.text, pointSize: Self.textPointSize)
        let blendsIn = item.map { item in
            KeyboardEmojiContrastCheck.blendsIn(
                item.text,
                keyTint: KeyboardStyle.keyTintColor(KeyboardStyle.keyFillColor).resolvedColor(with: traitCollection),
                backdrop: KeyboardStyle.keyBackdropStandInColor.resolvedColor(with: traitCollection)
            )
        } ?? false
        glyphView.setGlow(
            blendsIn ? KeyboardStyle.keyLabelColor.resolvedColor(with: traitCollection).withAlphaComponent(Self.emojiGlowOpacity) : nil,
            radius: Self.emojiGlowRadius
        )
    }

    /// Gives a suggestion the keys' colors, and the keys' pressed colors while it is touched.
    private func applyAppearance(to button: UIButton) {
        applyKeyAppearance(to: button, isShown: items.indices.contains(button.tag) && items[button.tag] != nil)
    }

    private func applyKeyAppearance(to button: UIButton, isShown: Bool) {
        guard isShown else {
            button.configuration?.baseForegroundColor = .clear
            button.backgroundColor = .clear
            button.layer.borderColor = UIColor.clear.cgColor
            return
        }
        let isPressed = button.isHighlighted
        button.configuration?.baseForegroundColor = isTrackpadModeActive ? .clear : KeyboardStyle.keyLabelColor
        button.backgroundColor = KeyboardStyle.keyTintColor(
            isPressed ? KeyboardStyle.keyPressedFillColor : KeyboardStyle.keyFillColor
        )
        button.layer.borderColor = isTrackpadModeActive
            ? UIColor.clear.cgColor
            : (isPressed ? KeyboardStyle.keyPressedBorderColor : KeyboardStyle.keyBorderColor)
                .resolvedColor(with: traitCollection)
                .cgColor
    }

    @objc
    private func handleTap(_ sender: UIButton) {
        guard items.indices.contains(sender.tag), let item = items[sender.tag] else { return }
        onItemSelected?(item)
    }

    @objc
    private func handleRescuedDictationTap() {
        onRescuedDictationSelected?()
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let tag = recognizer.view?.tag,
              items.indices.contains(tag),
              let item = items[tag] else { return }
        onItemLongPressed?(item)
    }
}
