import UIKit

final class KeyboardCapsLockButton: UIControl {
    private let backgroundView = UIView()
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let tintOverlay = UIView()
    private let imageView = UIImageView()

    var isLocked = false {
        didSet {
            updateAccessibility()
            updateVisualState(animated: true)
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: KeyboardStyle.cancelButtonSize, height: KeyboardStyle.cancelButtonSize)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        updateAccessibility()
        updateVisualState(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            updateVisualState(animated: true)
        }
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isAccessibilityElement = true

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        backgroundView.layer.borderWidth = 0.5
        backgroundView.layer.masksToBounds = false
        backgroundView.backgroundColor = .clear
        backgroundView.isUserInteractionEnabled = false

        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        blurEffectView.clipsToBounds = true
        blurEffectView.isUserInteractionEnabled = false

        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        tintOverlay.layer.cornerRadius = KeyboardStyle.keyCornerRadius
        tintOverlay.clipsToBounds = true
        tintOverlay.isUserInteractionEnabled = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false

        addSubview(backgroundView)
        backgroundView.addSubview(blurEffectView)
        backgroundView.addSubview(tintOverlay)
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

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func updateVisualState(animated: Bool) {
        let isPressed = isLocked || isHighlighted
        let colors = colorsForState(isPressed: isPressed, isEnabled: isEnabled)
        let transform = isPressed ? CGAffineTransform(scaleX: 0.985, y: 0.96) : .identity
        let shadow = isPressed ? KeyboardStyle.pressedKeyShadow : KeyboardStyle.keyShadow
        let symbolName = isLocked ? "capslock.fill" : "capslock"

        let applyState = {
            self.backgroundView.transform = transform
            self.tintOverlay.backgroundColor = colors.fill.withAlphaComponent(0.3)
            self.backgroundView.layer.borderColor = colors.border.cgColor
            self.backgroundView.layer.shadowColor = shadow.color.cgColor
            self.backgroundView.layer.shadowOpacity = shadow.opacity
            self.backgroundView.layer.shadowRadius = shadow.radius
            self.backgroundView.layer.shadowOffset = shadow.offset
            self.imageView.tintColor = colors.foreground
            self.imageView.image = UIImage(
                systemName: symbolName,
                withConfiguration: KeyboardStyle.keySymbolConfiguration
            )
        }

        if animated {
            UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                applyState()
            }
        } else {
            applyState()
        }
    }

    private func updateAccessibility() {
        accessibilityLabel = "Caps Lock"
        accessibilityValue = isLocked ? "On" : "Off"
    }

    private func colorsForState(isPressed: Bool, isEnabled: Bool) -> (fill: UIColor, border: UIColor, foreground: UIColor) {
        guard isEnabled else {
            return (
                fill: KeyboardStyle.keyDisabledFillColor,
                border: KeyboardStyle.keyDisabledBorderColor,
                foreground: KeyboardStyle.keyDisabledLabelColor
            )
        }

        if isPressed {
            return (
                fill: KeyboardStyle.keyPressedFillColor,
                border: traitCollection.userInterfaceStyle == .light ? .black : .white,
                foreground: KeyboardStyle.keyLabelColor
            )
        }

        return (
            fill: KeyboardStyle.keyFillColor,
            border: KeyboardStyle.keyBorderColor,
            foreground: KeyboardStyle.keyLabelColor
        )
    }
}
