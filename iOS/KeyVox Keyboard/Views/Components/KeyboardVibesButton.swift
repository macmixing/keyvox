import KeyVoxStyleRewrite
import UIKit

final class KeyboardVibesButton: UIControl {
    private let backgroundView = UIView()
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let tintOverlay = UIView()
    private let contentStackView = UIStackView()
    private let noneIconImageView = UIImageView(image: UIImage(named: "vibes-logo-bare")?.withRenderingMode(.alwaysTemplate))
    private let titleLabel = UILabel()
    private lazy var borderRenderer = KeyboardRoundedBorderRenderer(containerView: backgroundView)

    var title = "" {
        didSet {
            titleLabel.text = title
            updateNoneIconVisibility()
            updateAccessibility()
        }
    }

    var selectedVibeStyle: StyleRewriteStyle = .none {
        didSet {
            updateNoneIconVisibility()
            updateVisualState(animated: false)
        }
    }

    var isTrackpadModeActive = false {
        didSet {
            updateVisualState(animated: true)
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: KeyboardStyle.cancelButtonSize * 2, height: KeyboardStyle.cancelButtonSize)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        observeBorderAppearanceChanges()
        updateAccessibility()
        updateVisualState(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBorderPath()
    }

    override var isHighlighted: Bool {
        didSet {
            updateVisualState(animated: true)
        }
    }

    override var isEnabled: Bool {
        didSet {
            updateVisualState(animated: false)
        }
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .button

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.layer.cornerRadius = KeyboardStyle.keyCornerRadius
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

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = 4
        contentStackView.isUserInteractionEnabled = false

        noneIconImageView.translatesAutoresizingMaskIntoConstraints = false
        noneIconImageView.contentMode = .scaleAspectFit
        noneIconImageView.isUserInteractionEnabled = false
        noneIconImageView.isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.font = KeyboardStyle.specialKeyFont
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.isUserInteractionEnabled = false
        titleLabel.text = title

        addSubview(backgroundView)
        backgroundView.addSubview(blurEffectView)
        backgroundView.addSubview(tintOverlay)
        contentStackView.addArrangedSubview(noneIconImageView)
        contentStackView.addArrangedSubview(titleLabel)
        addSubview(contentStackView)
        _ = borderRenderer

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

            noneIconImageView.widthAnchor.constraint(equalToConstant: 14),
            noneIconImageView.heightAnchor.constraint(equalToConstant: 14),

            contentStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])

        updateNoneIconVisibility()
    }

    private func observeBorderAppearanceChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.updateVisualState(animated: false)
        }
    }

    private func updateVisualState(animated: Bool) {
        let colors = colorsForState(isPressed: isHighlighted, isEnabled: isEnabled)
        let resolvedBorderColor = colors.border.resolvedColor(with: traitCollection)
        let shadow = isHighlighted ? KeyboardStyle.pressedKeyShadow : KeyboardStyle.keyShadow

        let applyState = {
            self.backgroundView.transform = .identity
            self.tintOverlay.backgroundColor = colors.fill.withAlphaComponent(0.3)
            self.borderRenderer.strokeColor = self.isTrackpadModeActive ? UIColor.clear.cgColor : resolvedBorderColor.cgColor
            self.backgroundView.layer.shadowColor = shadow.color.cgColor
            self.backgroundView.layer.shadowOpacity = shadow.opacity
            self.backgroundView.layer.shadowRadius = shadow.radius
            self.backgroundView.layer.shadowOffset = shadow.offset
            self.titleLabel.textColor = colors.foreground
            self.noneIconImageView.tintColor = colors.foreground
            self.contentStackView.alpha = self.isTrackpadModeActive ? 0 : 1
        }

        if animated {
            UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                applyState()
            }
        } else {
            applyState()
        }
    }

    private func updateBorderPath() {
        borderRenderer.updatePath(
            cornerRadius: KeyboardStyle.keyCornerRadius,
            borderWidth: KeyboardStyle.keyBorderWidth
        )
    }

    private func updateAccessibility() {
        accessibilityLabel = title.isEmpty ? "KeyVox Vibes" : title
    }

    private func updateNoneIconVisibility() {
        noneIconImageView.isHidden = selectedVibeStyle != .none
    }

    private func colorsForState(isPressed: Bool, isEnabled: Bool) -> (fill: UIColor, border: UIColor, foreground: UIColor) {
        if isTrackpadModeActive {
            return (
                fill: KeyboardStyle.keyFillColor,
                border: .clear,
                foreground: KeyboardStyle.keyLabelColor
            )
        }

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
                foreground: isShowingSelectedVibe ? KeyboardStyle.pressedActiveForegroundColor(for: traitCollection) : KeyboardStyle.keyLabelColor
            )
        }

        return (
            fill: KeyboardStyle.keyFillColor,
            border: KeyboardStyle.keyBorderColor,
            foreground: isShowingSelectedVibe ? KeyboardStyle.activeForegroundColor(for: traitCollection) : KeyboardStyle.keyLabelColor
        )
    }

    private var isShowingSelectedVibe: Bool {
        selectedVibeStyle != .none
    }
}
