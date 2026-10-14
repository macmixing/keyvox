import UIKit

/// The emoji search field in the toolbar's place, as the system emoji keyboard draws it: a rounded
/// field with a magnifying glass, the search or the placeholder, while searching a blinking caret
/// after the search, and once there is a search a button that clears it. Tapping the field on the
/// emoji page starts searching.
final class KeyboardEmojiSearchFieldView: UIView {
    private typealias Geometry = KeyboardEmojiSearchGeometry.Measured

    /// The system keyboard's field over its keyboard's background, measured in screenshots with
    /// Tools/AppleKeyboardBaseline (`EmojiFrequentlyUsedProbeTests`), light and dark, and its
    /// caret in a screen recording.
    enum Measured {
        static let fillColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 57 / 255, green: 57 / 255, blue: 57 / 255, alpha: 1)
                : UIColor(red: 239 / 255, green: 240 / 255, blue: 245 / 255, alpha: 1)
        }
        /// The magnifying glass and the placeholder.
        static let secondaryColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 149 / 255, green: 149 / 255, blue: 149 / 255, alpha: 1)
                : UIColor(red: 137 / 255, green: 138 / 255, blue: 143 / 255, alpha: 1)
        }
        static let clearColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 108 / 255, green: 108 / 255, blue: 108 / 255, alpha: 1)
                : UIColor(red: 188 / 255, green: 189 / 255, blue: 194 / 255, alpha: 1)
        }
        static let caretColor = UIColor(red: 0, green: 132 / 255, blue: 252 / 255, alpha: 1)
        static let fontSize: CGFloat = 17
        /// The caret blinks once a second: it fades in, stays, fades out, and stays out, each for
        /// this part of the second.
        static let caretFadeIn: Double = 0.15
        static let caretOn: Double = 0.5
        static let caretFadeOut: Double = 0.15
        static let caretBlinkDuration: Double = 1
    }

    /// Matched to the same screenshots: the magnifying glass and the clear button each about 17
    /// points across.
    enum Drawn {
        static let magnifierPointSize: CGFloat = 16.7
        static let clearPointSize: CGFloat = 16.7
    }

    static let placeholder = "Search Emoji"

    var onBegin: (() -> Void)?
    var onClear: (() -> Void)?

    /// The search shown.
    var text = "" {
        didSet {
            guard text != oldValue else { return }
            textLabel.text = text
            update()
        }
    }

    /// Whether the field is searching, which shows its caret.
    var isSearching = false {
        didSet {
            guard isSearching != oldValue else { return }
            update()
        }
    }

    private let magnifierView = UIImageView()
    private let textLabel = UILabel()
    private let placeholderLabel = UILabel()
    private let caretView = UIView()
    private let clearButton = KeyboardHitTargetButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = Geometry.fieldCornerRadius
        layer.cornerCurve = .circular
        magnifierView.image = UIImage(
            systemName: "magnifyingglass",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Drawn.magnifierPointSize, weight: .medium)
        )
        // Named as the system keyboard names its magnifying glass, the element that starts a search.
        magnifierView.isAccessibilityElement = true
        magnifierView.accessibilityLabel = "Search"
        magnifierView.accessibilityTraits = .button
        let font = UIFont.systemFont(ofSize: Measured.fontSize)
        textLabel.font = font
        textLabel.textColor = .label
        // A long search keeps its end, where typing goes, in view.
        textLabel.lineBreakMode = .byTruncatingHead
        placeholderLabel.font = font
        placeholderLabel.text = Self.placeholder
        caretView.backgroundColor = Measured.caretColor
        caretView.isUserInteractionEnabled = false
        clearButton.setImage(
            UIImage(
                systemName: "xmark.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: Drawn.clearPointSize, weight: .regular)
            ),
            for: .normal
        )
        clearButton.minimumHitTargetSize = CGSize(width: Geometry.fieldHeight, height: Geometry.fieldHeight)
        clearButton.accessibilityLabel = "Clear text"
        clearButton.addTarget(self, action: #selector(handleClear), for: .touchUpInside)
        for view in [magnifierView, placeholderLabel, textLabel, caretView, clearButton] as [UIView] {
            addSubview(view)
        }
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.applyColors()
        }
        applyColors()
        update()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let midY = bounds.midY
        magnifierView.sizeToFit()
        magnifierView.center = CGPoint(x: Geometry.magnifierCenter, y: midY)
        clearButton.sizeToFit()
        clearButton.center = CGPoint(x: bounds.width - Geometry.clearCenterInset, y: midY)
        let textWidth = max(0, clearButton.frame.minX - Geometry.textStart)
        placeholderLabel.frame = CGRect(x: Geometry.textStart, y: 0, width: textWidth, height: bounds.height)
        let fittedWidth = min(textLabel.sizeThatFits(bounds.size).width, textWidth)
        textLabel.frame = CGRect(x: Geometry.textStart, y: 0, width: fittedWidth, height: bounds.height)
        caretView.frame = CGRect(
            x: Geometry.textStart + (text.isEmpty ? 0 : fittedWidth),
            y: midY - (Geometry.caretHeight / 2),
            width: Geometry.caretWidth,
            height: Geometry.caretHeight
        )
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // A view off screen loses its animations; the caret starts blinking again on screen.
        update()
    }

    private func update() {
        placeholderLabel.isHidden = text.isEmpty == false
        clearButton.isHidden = text.isEmpty
        caretView.isHidden = isSearching == false
        restartCaretBlink()
        setNeedsLayout()
    }

    /// Shows the caret and blinks it from there, as the system field does after each change.
    private func restartCaretBlink() {
        caretView.layer.removeAllAnimations()
        guard isSearching, window != nil else { return }
        let fadeOutStart = Measured.caretOn
        let offStart = fadeOutStart + Measured.caretFadeOut
        let fadeInStart = Measured.caretBlinkDuration - Measured.caretFadeIn
        let blink = CAKeyframeAnimation(keyPath: "opacity")
        blink.values = [1, 1, 0, 0, 1]
        blink.keyTimes = [0, fadeOutStart, offStart, fadeInStart, Measured.caretBlinkDuration].map {
            NSNumber(value: $0 / Measured.caretBlinkDuration)
        }
        blink.duration = Measured.caretBlinkDuration
        blink.repeatCount = .infinity
        caretView.layer.add(blink, forKey: "blink")
    }

    private func applyColors() {
        backgroundColor = Measured.fillColor.resolvedColor(with: traitCollection)
        magnifierView.tintColor = Measured.secondaryColor.resolvedColor(with: traitCollection)
        placeholderLabel.textColor = Measured.secondaryColor.resolvedColor(with: traitCollection)
        clearButton.tintColor = Measured.clearColor.resolvedColor(with: traitCollection)
    }

    @objc private func handleTap() {
        onBegin?()
    }

    @objc private func handleClear() {
        onClear?()
    }
}
