import Combine
import SwiftUI

enum iOSAppTheme {
    static let accent = Color.indigo
    static let screenBackground = Color(
        .sRGB,
        red: 26.0 / 255.0,
        green: 23.0 / 255.0,
        blue: 64.0 / 255.0,
        opacity: 1
    )
    static let cardFill = Color.white.opacity(0.05)
    static let cardStroke = Color.white.opacity(0.10)
    static let rowFill = Color.white.opacity(0.04)
    static let rowPressedFill = Color.white.opacity(0.08)
    static let rowStroke = Color.white.opacity(0.08)
    static let rowPressedStroke = Color.white.opacity(0.14)
    static let iconFill = Color.indigo.opacity(0.15)
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let rowCornerRadius: CGFloat = 10
}
