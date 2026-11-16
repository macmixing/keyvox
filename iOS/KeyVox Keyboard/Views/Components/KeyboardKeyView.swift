import UIKit

final class KeyboardKeyView: UIView {
    enum VisualState {
        case normal
        case pressed
        case trackpadActive
        case disabled
    }

    private let backgroundView = UIView()
    private let tintOverlay = UIView()
    /// Two labels taking turns: a letter switching case shows the label that already holds the
    /// other case instead of laying out new text, so switching case only shows and hides labels.
    private let titleLabels = [UILabel(), UILabel()]
    private var visibleTitleLabel: UILabel { titleLabels.first { $0.isHidden == false } ?? titleLabels[0] }
    private let imageView = UIImageView()
    /// The letters under a number pad digit, laid out by hand under the raised title.
    private let subtitleLabel = UILabel()
    private var titleCenterYConstraints: [NSLayoutConstraint] = []
    private lazy var borderRenderer = KeyboardRoundedBorderRenderer(containerView: backgroundView)

    private(set) var model: KeyboardKeyModel
    private(set) var visualState: VisualState = .normal
    private var widthUnits: CGFloat
    private var isTrackpadModeActive = false

    /// Everything the key's look follows; `apply` changes nothing when it is unchanged.
    private struct Appearance: Equatable {
        let model: KeyboardKeyModel
        let state: VisualState
        let isTrackpadModeActive: Bool
        let userInterfaceStyle: UIUserInterfaceStyle
    }

    private var appliedAppearance: Appearance?

    override var intrinsicContentSize: CGSize {
        CGSize(width: widthUnits * KeyboardStyle.keyUnitWidth, height: KeyboardStyle.keyHeight)
    }

    init(model: KeyboardKeyModel) {
        self.model = model
        self.widthUnits = model.widthUnits
        super.init(frame: .zero)
        configureView()
        observeBorderAppearanceChanges()
        apply(model: model, state: .normal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// How much the Display Zoom shrinks the keyboard's sizes, below 1 under Display Zoom; a number
    /// pad key shows its letters by the size it shows at, which the zoom changes.
    var displayZoomScale: CGFloat = 1 {
        didSet {
            guard displayZoomScale != oldValue else { return }
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        layoutSubtitle()
        super.layoutSubviews()
        updateBorderPath()
        updateShadowPath()
    }

    func apply(
        model: KeyboardKeyModel,
        state: VisualState,
        isTrackpadModeActive: Bool = false,
        animated: Bool = true
    ) {
        let appearance = Appearance(
            model: model,
            state: state,
            isTrackpadModeActive: isTrackpadModeActive,
            userInterfaceStyle: traitCollection.userInterfaceStyle
        )
        // Keys are applied again whenever the keyboard updates; one that looks the same is left alone.
        guard appearance != appliedAppearance else { return }
        let previousModel = appliedAppearance?.model
        let isNewModel = previousModel != model
        appliedAppearance = appearance
        self.model = model
        self.visualState = state
        self.isTrackpadModeActive = isTrackpadModeActive
        if isNewModel {
            accessibilityLabel = model.accessibilityLabel
            if widthUnits != model.widthUnits {
                widthUnits = model.widthUnits
                invalidateIntrinsicContentSize()
            }
            // A letter changing case keeps its font and has no symbol, so only its title changes.
            let titleFont = model.titleFont
            if previousModel == nil || visibleTitleLabel.font != titleFont {
                titleLabels.forEach { $0.font = titleFont }
            }
            showTitle(model.systemImageName == nil ? model.attributedTitle() : nil)
            subtitleLabel.attributedText = model.subtitle.map { subtitle in
                NSAttributedString(string: subtitle, attributes: [
                    .font: KeyboardStyle.numberPadSubtitleFont,
                    .kern: KeyboardStyle.numberPadSubtitleKerning,
                ])
            }
            setNeedsLayout()
            if previousModel == nil || previousModel?.systemImageName != model.systemImageName {
                imageView.image = model.systemImageName.flatMap { name in
                    UIImage(systemName: name, withConfiguration: KeyboardStyle.keySymbolConfiguration)
                }
                imageView.isHidden = model.systemImageName == nil
            }
        }

        let colors = colorsForCurrentState(model: model, state: state)
        let resolvedBorderColor = colors.border.resolvedColor(with: traitCollection)
        let effectiveBorderColor = isTrackpadModeActive ? UIColor.clear : resolvedBorderColor
        backgroundView.backgroundColor = .clear
        tintOverlay.backgroundColor = colors.fill
        borderRenderer.strokeColor = effectiveBorderColor.cgColor
        titleLabels.forEach { $0.textColor = colors.foreground }
        subtitleLabel.textColor = colors.foreground
        imageView.tintColor = colors.foreground

        let shadow = state == .pressed ? KeyboardStyle.pressedKeyShadow : KeyboardStyle.keyShadow
        backgroundView.layer.shadowColor = shadow.color.cgColor
        backgroundView.layer.shadowOpacity = shadow.opacity
        backgroundView.layer.shadowRadius = shadow.radius
        backgroundView.layer.shadowOffset = shadow.offset

        let transform: CGAffineTransform
        switch state {
        case .normal:
            transform = .identity
        case .pressed:
            transform = CGAffineTransform(scaleX: 0.985, y: 0.96)
        case .trackpadActive:
            transform = .identity
        case .disabled:
            transform = .identity
        }

        let applyBackgroundTransform = {
            self.backgroundView.transform = transform
        }
        if animated {
            UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                applyBackgroundTransform()
            }
        } else {
            applyBackgroundTransform()
        }
        let titleAlpha: CGFloat = isTrackpadModeActive ? 0 : 1
        let applyGlyphVisibility = {
            self.titleLabels.forEach { $0.alpha = titleAlpha }
            self.subtitleLabel.alpha = titleAlpha
            self.imageView.alpha = titleAlpha
        }
        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                applyGlyphVisibility()
            }
        } else {
            applyGlyphVisibility()
        }
    }

    func resetVisualState() {
        layer.removeAllAnimations()
        backgroundView.layer.removeAllAnimations()
        titleLabels.forEach { $0.layer.removeAllAnimations() }
        subtitleLabel.layer.removeAllAnimations()
        imageView.layer.removeAllAnimations()
        isTrackpadModeActive = false
        apply(model: model, state: .normal, isTrackpadModeActive: false, animated: false)
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        backgroundColor = .clear

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        backgroundView.layer.masksToBounds = false
        
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        tintOverlay.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        tintOverlay.clipsToBounds = true
        tintOverlay.isUserInteractionEnabled = false

        for (index, titleLabel) in titleLabels.enumerated() {
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.textAlignment = .center
            titleLabel.adjustsFontSizeToFitWidth = true
            titleLabel.minimumScaleFactor = 0.7
            titleLabel.isUserInteractionEnabled = false
            titleLabel.isHidden = index > 0
        }

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false

        subtitleLabel.textAlignment = .center
        subtitleLabel.isUserInteractionEnabled = false
        subtitleLabel.isHidden = true

        addSubview(backgroundView)
        backgroundView.addSubview(tintOverlay)
        titleLabels.forEach(addSubview)
        addSubview(subtitleLabel)
        addSubview(imageView)
        _ = borderRenderer

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tintOverlay.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            tintOverlay.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        titleCenterYConstraints = titleLabels.map { $0.centerYAnchor.constraint(equalTo: centerYAnchor) }
        NSLayoutConstraint.activate(titleCenterYConstraints)
        NSLayoutConstraint.activate(titleLabels.flatMap { titleLabel in
            [
                titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            ]
        })
    }

    /// Shows `title`, in the label already holding it if one does, otherwise in the label not
    /// showing, so the title it replaces stays ready for the next switch back.
    private func showTitle(_ title: NSAttributedString?) {
        let current = visibleTitleLabel
        guard current.attributedText != title else { return }
        let label = titleLabels.first { $0 !== current && $0.attributedText == title }
            ?? titleLabels.first { $0 !== current }!
        if label.attributedText != title {
            label.attributedText = title
        }
        label.isHidden = false
        current.isHidden = true
    }

    /// Raises a number pad digit's title and puts its letters under it, on keys tall enough for
    /// both; shorter keys, such as in landscape on iPhone, show the digit alone. Under Display Zoom a
    /// key is judged by the size it shows at, as the zoom enlarges it.
    private func layoutSubtitle() {
        let showsSubtitle = model.subtitle != nil
            && bounds.height >= KeyboardStyle.numberPadSubtitleMinimumKeyHeight
                * displayZoomScale
        let titleOffset = showsSubtitle ? -bounds.height * KeyboardStyle.numberPadTitleRaise : 0
        for constraint in titleCenterYConstraints where constraint.constant != titleOffset {
            constraint.constant = titleOffset
        }
        subtitleLabel.isHidden = showsSubtitle == false || model.subtitle?.isEmpty != false
        guard subtitleLabel.isHidden == false else { return }
        subtitleLabel.sizeToFit()
        // The kerning follows the last letter too, so the letters sit that much left of center.
        subtitleLabel.center = CGPoint(
            x: bounds.midX + KeyboardStyle.numberPadSubtitleKerning / 2,
            y: bounds.midY + bounds.height * KeyboardStyle.numberPadSubtitleDrop
        )
    }

    private func observeBorderAppearanceChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self, KeyboardThemeTrait.self]) { (self: Self, _: UITraitCollection) in
            self.apply(
                model: self.model,
                state: self.visualState,
                isTrackpadModeActive: self.isTrackpadModeActive,
                animated: false
            )
        }
    }

    private func updateBorderPath() {
        borderRenderer.updatePath(
            cornerRadius: KeyboardStyle.keyCornerRadius,
            borderWidth: KeyboardStyle.keyBorderWidth
        )
    }

    /// Gives the shadow the key's rounded shape, so it is not worked out from the key's
    /// contents each frame.
    private func updateShadowPath() {
        backgroundView.layer.shadowPath = UIBezierPath(
            roundedRect: backgroundView.bounds,
            cornerRadius: KeyboardStyle.keyCornerRadius
        ).cgPath
    }

    private func colorsForCurrentState(
        model: KeyboardKeyModel,
        state: VisualState
    ) -> (fill: UIColor, border: UIColor, foreground: UIColor) {
        // An action key is solid blue, and pressed it looks like a letter key, as the system
        // keyboard's does.
        if model.isActionKey, state == .normal || state == .trackpadActive {
            return (
                fill: KeyboardStyle.actionKeyFillColor,
                border: .clear,
                foreground: KeyboardStyle.actionKeyLabelColor
            )
        }
        if model.isActionKey, state == .pressed {
            return (
                fill: KeyboardStyle.keyTintColor(KeyboardStyle.keyFillColor),
                border: KeyboardStyle.keyBorderColor,
                foreground: KeyboardStyle.keyLabelColor
            )
        }
        switch state {
        case .disabled:
            return (
                fill: KeyboardStyle.keyTintColor(
                    model.isSpecialKey ? KeyboardStyle.specialKeyDisabledFillColor : KeyboardStyle.keyDisabledFillColor
                ),
                border: KeyboardStyle.keyDisabledBorderColor,
                foreground: KeyboardStyle.keyDisabledLabelColor
            )
        case .normal:
            return (
                fill: KeyboardStyle.keyTintColor(
                    model.isSpecialKey ? KeyboardStyle.specialKeyFillColor : KeyboardStyle.keyFillColor
                ),
                border: KeyboardStyle.keyBorderColor,
                foreground: KeyboardStyle.keyLabelColor
            )
        case .pressed:
            return (
                fill: KeyboardStyle.keyTintColor(
                    model.isSpecialKey ? KeyboardStyle.specialKeyPressedFillColor : KeyboardStyle.keyPressedFillColor
                ),
                border: KeyboardStyle.keyPressedBorderColor,
                foreground: KeyboardStyle.keyLabelColor
            )
        case .trackpadActive:
            return (
                fill: KeyboardStyle.keyTintColor(
                    model.isSpecialKey ? KeyboardStyle.specialKeyFillColor : KeyboardStyle.keyFillColor
                ),
                border: .clear,
                foreground: KeyboardStyle.keyLabelColor
            )
        }
    }
}
