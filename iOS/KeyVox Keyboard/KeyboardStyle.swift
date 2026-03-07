import UIKit

enum KeyboardStyle {
    static let minHeight: CGFloat = 72
    static let horizontalPadding: CGFloat = 16
    static let buttonSize: CGFloat = 44
    static let micButtonSize: CGFloat = 52
    static let buttonCornerRadius: CGFloat = 14
    static let micButtonCornerRadius: CGFloat = 18
    static let stackSpacing: CGFloat = 12

    static let backgroundColor = UIColor.systemBackground
    static let borderColor = UIColor.separator.withAlphaComponent(0.35)
    static let labelColor = UIColor.label
    static let secondaryLabelColor = UIColor.secondaryLabel
    static let idleMicColor = UIColor.systemBlue
    static let recordingMicColor = UIColor.systemRed
    static let pendingMicColor = UIColor.systemGray2
    static let buttonFillColor = UIColor.secondarySystemBackground

    static let statusFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .medium)
    static let buttonSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
}
