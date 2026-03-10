import UIKit

final class KeyboardKeyView: UIView {
    enum VisualState {
        case normal
        case pressed
        case trackpadActive
        case disabled
    }

    private let backgroundView = UIView()
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let tintOverlay = UIView()
    private let titleLabel = UILabel()
    private let imageView = UIImageView()

    private(set) var model: KeyboardKeyModel
    private(set) var visualState: VisualState = .normal
    private var widthUnits: CGFloat

    override var intrinsicContentSize: CGSize {
        CGSize(width: widthUnits * KeyboardStyle.keyUnitWidth, height: KeyboardStyle.keyHeight)
    }

    init(model: KeyboardKeyModel) {
        self.model = model
        self.widthUnits = model.widthUnits
        super.init(frame: .zero)
        configureView()
        apply(model: model, state: .normal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(model: KeyboardKeyModel, state: VisualState, isTrackpadModeActive: Bool = false) {
        self.model = model
        self.widthUnits = model.widthUnits
        self.visualState = state
        accessibilityLabel = model.accessibilityLabel
        invalidateIntrinsicContentSize()

        let colors = colorsForCurrentState(model: model, state: state)
        backgroundView.backgroundColor = .clear
        tintOverlay.backgroundColor = colors.fill.withAlphaComponent(0.3)
        backgroundView.layer.borderColor = colors.border.cgColor
        titleLabel.textColor = colors.foreground
        imageView.tintColor = colors.foreground

        titleLabel.font = model.titleFont
        if model.systemImageName == nil {
            let attributes: [NSAttributedString.Key: Any] = [
                .baselineOffset: model.titleBaselineOffset
            ]
            titleLabel.attributedText = NSAttributedString(string: model.title, attributes: attributes)
        } else {
            titleLabel.attributedText = nil
        }
        imageView.image = model.systemImageName.flatMap { name in
            UIImage(systemName: name, withConfiguration: KeyboardStyle.keySymbolConfiguration)
        }
        imageView.isHidden = model.systemImageName == nil

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

        UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.backgroundView.transform = transform
        }
        let titleAlpha: CGFloat = isTrackpadModeActive ? 0 : 1
        UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.titleLabel.alpha = titleAlpha
            self.imageView.alpha = titleAlpha
        }
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        backgroundColor = .clear

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        backgroundView.layer.borderWidth = 0.5
        backgroundView.layer.masksToBounds = false
        
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        blurEffectView.clipsToBounds = true
        blurEffectView.isUserInteractionEnabled = false
        
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        tintOverlay.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        tintOverlay.clipsToBounds = true
        tintOverlay.isUserInteractionEnabled = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.isUserInteractionEnabled = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false

        addSubview(backgroundView)
        backgroundView.addSubview(blurEffectView)
        backgroundView.addSubview(tintOverlay)
        addSubview(titleLabel)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurEffectView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            blurEffectView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),

            tintOverlay.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            tintOverlay.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func colorsForCurrentState(model: KeyboardKeyModel, state: VisualState) -> (fill: UIColor, border: UIColor, foreground: UIColor) {
        switch state {
        case .disabled:
            return (
                fill: model.isSpecialKey ? KeyboardStyle.specialKeyDisabledFillColor : KeyboardStyle.keyDisabledFillColor,
                border: KeyboardStyle.keyDisabledBorderColor,
                foreground: KeyboardStyle.keyDisabledLabelColor
            )
        case .normal:
            return (
                fill: model.isSpecialKey ? KeyboardStyle.specialKeyFillColor : KeyboardStyle.keyFillColor,
                border: KeyboardStyle.keyBorderColor,
                foreground: KeyboardStyle.keyLabelColor
            )
        case .pressed:
            return (
                fill: model.isSpecialKey ? KeyboardStyle.specialKeyPressedFillColor : KeyboardStyle.keyPressedFillColor,
                border: KeyboardStyle.keyPressedBorderColor,
                foreground: KeyboardStyle.keyLabelColor
            )
        case .trackpadActive:
            return (
                fill: model.isSpecialKey ? KeyboardStyle.specialKeyFillColor : KeyboardStyle.keyFillColor,
                border: KeyboardStyle.keyBorderColor,
                foreground: KeyboardStyle.keyLabelColor
            )
        }
    }
}
