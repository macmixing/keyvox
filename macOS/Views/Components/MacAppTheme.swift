import SwiftUI

enum MacAppTheme {
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
    static let promoCardFill = Color.yellow.opacity(0.14)
    static let promoCardStroke = Color.yellow.opacity(0.32)
    static let rowFill = Color.white.opacity(0.04)
    static let rowPressedFill = Color.white.opacity(0.08)
    static let rowStroke = Color.white.opacity(0.08)
    static let rowPressedStroke = Color.white.opacity(0.14)
    static let iconFill = accent.opacity(0.15)
    static let sidebarFill = Color.white.opacity(0.02)
    static let sidebarSelectionFill = accent.opacity(0.30)
    static let sidebarHoverFill = Color.white.opacity(0.05)
    static let tipFill = Color.white.opacity(0.03)
    static let windowStroke = Color.white.opacity(0.12)
    static let closeButtonForeground = Color.white.opacity(0.8)
}
