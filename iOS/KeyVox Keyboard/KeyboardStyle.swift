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
    static let micButtonSize: CGFloat = 52
    static let buttonCornerRadius: CGFloat = 14
    static let micButtonCornerRadius: CGFloat = 18

    static let keyHeight: CGFloat = 48
    static let keyUnitWidth: CGFloat = 34
    static let keyCornerRadius: CGFloat = 8
    static let popupCornerRadius: CGFloat = 18
    static let popupStemWidth: CGFloat = 34
    static let popupStemHeight: CGFloat = 28
    static let popupStemCornerRadius: CGFloat = 10

    static let backgroundColor = UIColor.clear
    static let borderColor = UIColor.clear
    static let labelColor = UIColor.label
    static let secondaryLabelColor = UIColor.secondaryLabel
    static let idleMicColor = UIColor.systemBlue
    static let recordingMicColor = UIColor.systemRed
    static let pendingMicColor = UIColor.systemGray2
    static let buttonFillColor = UIColor.secondarySystemBackground

    static let keyFillColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.34, green: 0.35, blue: 0.38, alpha: 1) : .white
    }
    static let keyPressedFillColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.46, green: 0.47, blue: 0.5, alpha: 1) : UIColor(red: 0.84, green: 0.86, blue: 0.9, alpha: 1)
    }
    static let specialKeyFillColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.28, green: 0.29, blue: 0.32, alpha: 1) : UIColor(red: 0.80, green: 0.82, blue: 0.86, alpha: 1)
    }
    static let specialKeyPressedFillColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.4, green: 0.41, blue: 0.45, alpha: 1) : UIColor(red: 0.72, green: 0.75, blue: 0.8, alpha: 1)
    }
    static let keyDisabledFillColor = UIColor.tertiarySystemFill
    static let specialKeyDisabledFillColor = UIColor.quaternarySystemFill
    static let keyBorderColor = UIColor.separator.withAlphaComponent(0.18)
    static let keyPressedBorderColor = UIColor.separator.withAlphaComponent(0.32)
    static let keyDisabledBorderColor = UIColor.separator.withAlphaComponent(0.08)
    static let keyLabelColor = UIColor.label
    static let keyDisabledLabelColor = UIColor.secondaryLabel.withAlphaComponent(0.7)

    static let popupFillColor = UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1) : .white
    }
    static let popupBorderColor = UIColor.separator.withAlphaComponent(0.16)
    static let popupLabelColor = UIColor.black

    static let statusFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .medium)
    static let keyFont = UIFont.systemFont(ofSize: 22, weight: .regular)
    static let specialKeyFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    static let popupFont = UIFont.systemFont(ofSize: 32, weight: .medium)
    static let buttonSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    static let keySymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)

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
    static let popupShadow = Shadow(
        color: UIColor.black,
        opacity: 0.18,
        radius: 8,
        offset: CGSize(width: 0, height: 4)
    )
}
