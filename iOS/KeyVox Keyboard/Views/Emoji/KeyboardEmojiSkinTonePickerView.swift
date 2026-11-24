import UIKit

/// The skin-tone picker of a held emoji, in the system emoji keyboard's look: a panel, joined to
/// the emoji by a stem when it has one, the emoji as it comes, a divider, its skin tones, and on the
/// emoji page the choice under the finger under a light overlay.
final class KeyboardEmojiSkinTonePickerView: UIView {
    /// The system emoji keyboard's pickers over its keyboard's background, measured in screenshots
    /// with Tools/AppleKeyboardBaseline (`EmojiFrequentlyUsedProbeTests`), light and dark.
    struct Style {
        let fillColor: UIColor
        let dividerColor: UIColor
        let panelCornerRadius: CGFloat
        let stemCornerRadius: CGFloat
        let shadow: KeyboardStyle.Shadow?

        /// The emoji page's picker.
        static let page = Style(
            fillColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 73 / 255, green: 72 / 255, blue: 70 / 255, alpha: 1)
                    : UIColor(red: 197 / 255, green: 199 / 255, blue: 201 / 255, alpha: 1)
            },
            dividerColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 101 / 255, green: 97 / 255, blue: 88 / 255, alpha: 1)
                    : UIColor(red: 176 / 255, green: 176 / 255, blue: 172 / 255, alpha: 1)
            },
            panelCornerRadius: 10,
            // The stem's bottom corners take the panel's rounding, which was not measured on the stem.
            stemCornerRadius: 10,
            shadow: nil
        )

        /// A search result's picker.
        static let searchResult = Style(
            fillColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 107 / 255, green: 107 / 255, blue: 107 / 255, alpha: 1)
                    : UIColor(red: 254 / 255, green: 254 / 255, blue: 254 / 255, alpha: 1)
            },
            dividerColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 122 / 255, green: 122 / 255, blue: 122 / 255, alpha: 1)
                    : UIColor(red: 229 / 255, green: 229 / 255, blue: 229 / 255, alpha: 1)
            },
            panelCornerRadius: KeyboardEmojiSearchSkinTonePickerLayout.Measured.panelCornerRadius,
            stemCornerRadius: KeyboardEmojiSearchSkinTonePickerLayout.Measured.stemCornerRadius,
            // Fitted to how the system panel's shadow fades beside and below it in light mode.
            shadow: KeyboardStyle.Shadow(color: .black, opacity: 0.26, radius: 7, offset: CGSize(width: 0, height: 5))
        )
    }

    private let shapeLayer = CAShapeLayer()
    private let dividerView = UIView()
    private let highlightView = KeyboardEmojiChoiceHighlightView()
    private var choiceViews: [KeyboardEmojiGlyphView] = []
    private var choiceCenters: [CGPoint] = []
    private var style = Style.page
    /// How much the picker's corners, shadow, and highlight shrink, below 1 under Display Zoom.
    var sizeScale: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        layer.addSublayer(shapeLayer)
        addSubview(dividerView)
        addSubview(highlightView)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.applyColors()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows `choices`, the emoji as it comes and then its skin tones, centered on `choiceCenters`
    /// in a panel, joined by `stem` when there is one, in `style`, in this view's coordinates, none
    /// chosen yet.
    func present(
        panel: CGRect,
        stem: CGRect?,
        divider: CGRect,
        choiceCenters: [CGPoint],
        choices: [String],
        font: UIFont,
        style: Style
    ) {
        self.choiceCenters = choiceCenters
        self.style = style
        // The panel's corners and shadow shrink by the Display Zoom, as its parts do.
        let path = KeyboardEmojiPickerPanelShape.path(
            panel: panel,
            stem: stem,
            panelCornerRadius: style.panelCornerRadius * sizeScale,
            stemCornerRadius: style.stemCornerRadius * sizeScale
        )
        shapeLayer.path = path.cgPath
        shapeLayer.shadowPath = path.cgPath
        shapeLayer.shadowColor = style.shadow?.color.cgColor
        shapeLayer.shadowOpacity = style.shadow?.opacity ?? 0
        shapeLayer.shadowRadius = (style.shadow?.radius ?? 0) * sizeScale
        let shadowOffset = style.shadow?.offset ?? .zero
        shapeLayer.shadowOffset = CGSize(width: shadowOffset.width * sizeScale, height: shadowOffset.height * sizeScale)
        dividerView.frame = divider
        while choiceViews.count < choices.count {
            let choiceView = KeyboardEmojiGlyphView()
            choiceViews.append(choiceView)
            addSubview(choiceView)
        }
        for (index, choiceView) in choiceViews.enumerated() {
            choiceView.isHidden = index >= choices.count
            guard index < choices.count else { continue }
            choiceView.show(choices[index], pointSize: font.pointSize)
            // The emoji is drawn centered in the view, so only its center matters.
            choiceView.bounds = CGRect(x: 0, y: 0, width: font.lineHeight, height: font.lineHeight)
            choiceView.center = choiceCenters[index]
        }
        select(nil)
        applyColors()
        isHidden = false
    }

    /// Highlights choice `index`, or none.
    func select(_ index: Int?) {
        guard let index, choiceCenters.indices.contains(index) else {
            highlightView.isHidden = true
            return
        }
        highlightView.show(centeredAt: choiceCenters[index], sizeScale: sizeScale)
        // The highlight goes under the choices.
        insertSubview(highlightView, belowSubview: choiceViews[0])
    }

    func dismiss() {
        isHidden = true
        choiceCenters = []
    }

    private func applyColors() {
        shapeLayer.fillColor = style.fillColor.resolvedColor(with: traitCollection).cgColor
        dividerView.backgroundColor = style.dividerColor.resolvedColor(with: traitCollection)
    }
}
