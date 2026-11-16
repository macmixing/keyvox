import UIKit

/// How much Display Zoom enlarges the keyboard. Display Zoom shows every point larger on the
/// screen, so the keyboard's fixed sizes scale down by the same amount to take the same part of
/// the screen as with Display Zoom off.
struct KeyboardDisplayZoom: Equatable, Sendable {
    /// The factor the keyboard's sizes are multiplied by: 1 without Display Zoom, below 1 with it.
    let sizeScale: CGFloat

    static let none = KeyboardDisplayZoom(sizeScale: 1)

    /// The pixels of the 5.4-inch iPhone 12 mini's and 13 mini's screen, in portrait. Without
    /// Display Zoom they draw 375 by 812 points at 3x and shrink that to fit these pixels, so their
    /// own pixels per point are not their drawing scale.
    private static let shrunkScreenPixels = CGSize(width: 1080, height: 2340)
    private static let shrunkScreenStandardWidth: CGFloat = 375

    /// Reads the zoom from the screen: the screen's own pixels per point without Display Zoom over
    /// its own pixels per point now (`nativeScale`). Without Display Zoom the first is the scale it
    /// draws at, except on a screen that shrinks what it draws to fit.
    static func resolve(for screen: UIScreen?) -> KeyboardDisplayZoom {
        guard let screen, screen.nativeScale > 0 else { return .none }
        let standardNativeScale = screen.nativeBounds.size == shrunkScreenPixels
            ? shrunkScreenPixels.width / shrunkScreenStandardWidth
            : screen.scale
        return KeyboardDisplayZoom(sizeScale: standardNativeScale / screen.nativeScale)
    }
}
