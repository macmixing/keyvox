import UIKit

enum KeyboardStyle {
    struct Shadow {
        let color: UIColor
        let opacity: Float
        let radius: CGFloat
        let offset: CGSize
    }

    static let keyboardHeight: CGFloat = 286
    static let minHeight: CGFloat = 286
    static let horizontalPadding: CGFloat = 4
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 4
    static let sectionSpacing: CGFloat = 14
    static let stackSpacing: CGFloat = 12
    static let keyboardRowSpacing: CGFloat = 8
    static let keySpacing: CGFloat = 6
    static let buttonSize: CGFloat = 44
    static let buttonCornerRadius: CGFloat = 14

    static let keyHeight: CGFloat = 48
    static let keyUnitWidth: CGFloat = 34
    static let keyCornerRadius: CGFloat = 8
    static let popupWidthMultiplier: CGFloat = 1.15
    static let popupHeightMultiplier: CGFloat = 1.25
    static let popupContentInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    static let popupMinEdgeInset: CGFloat = 2
    static let popupCornerRadius: CGFloat = 10
    static let popupBorderWidth: CGFloat = 0.6
    static let popupShadowColor = UIColor.black
    static let popupShadowOpacity: Float = 0.25
    static let popupShadowRadius: CGFloat = 4
    static let popupShadowOffset = CGSize(width: 0, height: 3)
    static let popupFillColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.62, green: 0.63, blue: 0.78, alpha: 1) : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    }
    static let popupBorderColor = UIColor { trait in
        trait.userInterfaceStyle == .light
            ? UIColor.separator.withAlphaComponent(0.45)
            : UIColor.white.withAlphaComponent(0.50)
    }
    static let popupLabelColor = UIColor.black
    static let popupFont = UIFont.systemFont(ofSize: 32, weight: .medium)

    static let backgroundColor = UIColor.clear
    static let borderColor = UIColor.clear
    static let labelColor = UIColor.label
    static let secondaryLabelColor = UIColor.secondaryLabel
    static let buttonFillColor = UIColor.secondarySystemBackground
    static let controlBlurEffectStyle: UIBlurEffect.Style = .systemThinMaterial
    static let cancelButtonSize: CGFloat = 32
    static let cancelButtonBorderColor = UIColor.systemIndigo
    static let cancelButtonIconColor = UIColor.systemRed
    static let cancelButtonBorderWidth: CGFloat = 0.5
    static let keyBorderWidth: CGFloat = 0.5

    static let keyFillColor = UIColor(red: 0.67, green: 0.67, blue: 0.92, alpha: 1)
    static let keyPressedFillColor = UIColor(red: 0.29, green: 0.31, blue: 0.55, alpha: 1)
    static let specialKeyFillColor = UIColor(red: 0.35, green: 0.36, blue: 0.66, alpha: 1)
    static let specialKeyPressedFillColor = UIColor(red: 0.19, green: 0.20, blue: 0.36, alpha: 1)
    static let keyDisabledFillColor = UIColor.tertiarySystemFill
    static let specialKeyDisabledFillColor = UIColor.quaternarySystemFill
    static let keyBorderColor = UIColor { trait in
        trait.userInterfaceStyle == .light
            ? UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 0.35)
            : UIColor.white.withAlphaComponent(0.15)
    }
    static let keyPressedBorderColor = UIColor { trait in
        trait.userInterfaceStyle == .light
            ? UIColor.separator.withAlphaComponent(0.20)
            : UIColor.white.withAlphaComponent(0.04)
    }
    static let keyDisabledBorderColor = UIColor { trait in
        trait.userInterfaceStyle == .light
            ? UIColor.separator.withAlphaComponent(0.08)
            : UIColor.white.withAlphaComponent(0.08)
    }
    static let keyLabelColor = UIColor.label
    static let keyDisabledLabelColor = UIColor.secondaryLabel.withAlphaComponent(0.7)

    static let keyFont = UIFont.systemFont(ofSize: 22, weight: .regular)
    static let specialKeyFont = UIFont.systemFont(ofSize: 17)
    static let buttonSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    static let keySymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
    static let cancelButtonSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)

    static let keyShadow = Shadow(
        color: UIColor.black,
        opacity: 0.12,
        radius: 0.8,
        offset: CGSize(width: 0, height: 1)
    )
    static let pressedKeyShadow = Shadow(
        color: UIColor.black,
        opacity: 0.18,
        radius: 2,
        offset: CGSize(width: 0, height: 2)
    )
}
