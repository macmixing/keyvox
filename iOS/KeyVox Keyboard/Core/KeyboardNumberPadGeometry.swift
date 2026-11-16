import CoreGraphics

/// How wide the number pad's keys reach, as the system's number pad sits: across the keyboard
/// upright, and on its side as wide as the screen less `KeyboardStyle.numberPadLandscapeScreenSideInset`
/// at each side, whatever the screen's width, never wider than the key grid and across it where
/// the screen leaves no width. The pad sits centered in the key grid, which the system centers on
/// the screen.
enum KeyboardNumberPadGeometry {
    static func width(gridWidth: CGFloat, screenWidth: CGFloat, isLandscape: Bool) -> CGFloat {
        guard isLandscape else { return gridWidth }
        let padWidth = screenWidth - (KeyboardStyle.numberPadLandscapeScreenSideInset * 2)
        return padWidth > 0 ? min(gridWidth, padWidth) : gridWidth
    }
}
