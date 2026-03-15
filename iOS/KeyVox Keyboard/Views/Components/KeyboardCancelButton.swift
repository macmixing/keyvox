import UIKit

final class KeyboardCancelButton: UIControl {
    private let fillAlpha: CGFloat = 0.3
    private let highlightedBorderAlpha: CGFloat = 0.3
    private let normalBorderAlpha: CGFloat = 0.7
    private let iconAlpha: CGFloat = 0.8
    private let highlightedIconAlpha: CGFloat = 0.4
    private let normalIconAlpha: CGFloat = 0.92
    private let pressAnimationDuration: TimeInterval = 0.08

    private let backgroundView = UIView()
    private let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: KeyboardStyle.controlBlurEffectStyle))
    private let tintOverlay = UIView()
    private let iconImageView = UIImageView()
    private lazy var borderRenderer = KeyboardRoundedBorderRenderer(containerView: backgroundView)

    var isTrackpadModeActive = false {
        didSet {
            updateVisualState(animated: true)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: KeyboardStyle.cancelButtonSize, height: KeyboardStyle.cancelButtonSize)
    }
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        configureView()
        observeBorderAppearanceChanges()
        updateAccessibility()
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
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityTraits = [.button]
        
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
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.isUserInteractionEnabled = false
        
        iconImageView.image = UIImage(
            systemName: "xmark",
            withConfiguration: KeyboardStyle.cancelButtonSymbolConfiguration
        )
        
        addSubview(backgroundView)
        backgroundView.addSubview(blurEffectView)
        backgroundView.addSubview(tintOverlay)
        addSubview(iconImageView)
        _ = borderRenderer
        
        updateVisualState(animated: false)
        
        let shadow = KeyboardStyle.keyShadow
        backgroundView.layer.shadowColor = shadow.color.cgColor
        backgroundView.layer.shadowOpacity = shadow.opacity
        backgroundView.layer.shadowRadius = shadow.radius
        backgroundView.layer.shadowOffset = shadow.offset
        
        setupConstraints()
    }

    private func observeBorderAppearanceChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.updateVisualState(animated: false)
        }
    }
    
    private func updateVisualState(animated: Bool) {
        let transform: CGAffineTransform = isHighlighted ? CGAffineTransform(scaleX: 0.985, y: 0.96) : .identity
        let colors = colorsForState(isHighlighted: isHighlighted)
        let resolvedBorderColor = colors.border.resolvedColor(with: traitCollection)
        let shadow = isHighlighted ? KeyboardStyle.pressedKeyShadow : KeyboardStyle.keyShadow
        
        let animations = {
            self.backgroundView.transform = transform
            self.tintOverlay.backgroundColor = colors.fill.withAlphaComponent(self.fillAlpha)
            self.borderRenderer.strokeColor = self.isTrackpadModeActive ? UIColor.clear.cgColor : resolvedBorderColor.cgColor
            self.iconImageView.tintColor = colors.icon
            self.iconImageView.alpha = self.isTrackpadModeActive ? 0 : (self.isHighlighted ? self.highlightedIconAlpha : self.normalIconAlpha)
            
            self.backgroundView.layer.shadowColor = shadow.color.cgColor
            self.backgroundView.layer.shadowOpacity = shadow.opacity
            self.backgroundView.layer.shadowRadius = shadow.radius
            self.backgroundView.layer.shadowOffset = shadow.offset
        }
        
        if animated {
            UIView.animate(
                withDuration: pressAnimationDuration,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: animations
            )
        } else {
            animations()
        }
    }
    private func updateBorderPath() {
        borderRenderer.updatePath(
            cornerRadius: KeyboardStyle.keyCornerRadius,
            borderWidth: KeyboardStyle.cancelButtonBorderWidth
        )
    }
    
    private func setupConstraints() {
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
            
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func updateAccessibility() {
        accessibilityLabel = "Cancel recording"
        accessibilityHint = "Cancels the current recording without transcribing"
    }
    
    private func colorsForState(isHighlighted: Bool) -> (fill: UIColor, border: UIColor, icon: UIColor) {
        if isHighlighted {
            return (
                fill: KeyboardStyle.keyPressedFillColor,
                border: KeyboardStyle.cancelButtonBorderColor.withAlphaComponent(highlightedBorderAlpha),
                icon: KeyboardStyle.cancelButtonIconColor.withAlphaComponent(iconAlpha)
            )
        } else {
            return (
                fill: KeyboardStyle.keyFillColor,
                border: KeyboardStyle.cancelButtonBorderColor.withAlphaComponent(normalBorderAlpha),
                icon: KeyboardStyle.cancelButtonIconColor.withAlphaComponent(iconAlpha)
            )
        }
    }
}
