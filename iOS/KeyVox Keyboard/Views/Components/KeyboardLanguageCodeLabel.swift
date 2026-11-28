import UIKit

/// The language the keyboard types in, written faintly by its short code at the bottom right of the
/// space bar for as long as the keyboard has more than one language, as Apple's keyboard writes it;
/// VoiceOver reads its full name.
final class KeyboardLanguageCodeLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(
            ofSize: KeyboardStyle.languageCodeFontSize,
            weight: .regular,
            width: .compressed
        )
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Draws the code faintly in `color`, the key's label color, as faint as Apple's keyboard draws
    /// it in each appearance.
    func setColor(_ color: UIColor) {
        textColor = UIColor { traits in
            let resolved = color.resolvedColor(with: traits)
            let opacity = traits.userInterfaceStyle == .dark
                ? KeyboardStyle.languageCodeDarkOpacity
                : KeyboardStyle.languageCodeLightOpacity
            return resolved.withAlphaComponent(resolved.cgColor.alpha * opacity)
        }
    }

    /// Shows `code`, read as `name`, or nothing when `code` is nil.
    func show(code: String?, name: String?) {
        text = code
        accessibilityLabel = name
        isHidden = code == nil
        isAccessibilityElement = code != nil
    }
}
