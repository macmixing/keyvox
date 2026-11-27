import UIKit

/// The language the keyboard switched to, written faintly by its short code at the bottom right of
/// the space bar and fading out about two seconds later; VoiceOver reads its full name.
final class KeyboardLanguageCodeLabel: UILabel {
    private static let shownOpacity: CGFloat = 0.55
    private static let holdDuration: TimeInterval = 1.6
    private static let fadeDuration: TimeInterval = 0.4

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = .systemFont(ofSize: 11, weight: .medium)
        alpha = 0
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows `code`, read as `name`, and fades it out.
    func show(code: String, name: String) {
        text = code
        accessibilityLabel = name
        isAccessibilityElement = true
        layer.removeAllAnimations()
        alpha = Self.shownOpacity
        // The fade starts from the opacity just set, not from what is on screen: on screen the
        // label is still as its last fade left it, so a fade from there would stay invisible.
        UIView.animate(
            withDuration: Self.fadeDuration,
            delay: Self.holdDuration,
            options: [.allowUserInteraction]
        ) {
            self.alpha = 0
        } completion: { finished in
            guard finished else { return }
            self.isAccessibilityElement = false
        }
    }
}
