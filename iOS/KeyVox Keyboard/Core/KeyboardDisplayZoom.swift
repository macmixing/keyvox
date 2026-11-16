import UIKit

/// How much Display Zoom enlarges the keyboard. Display Zoom shows every point larger on the
/// screen, so the keyboard's fixed heights scale down by the same amount to take the same part of
/// the screen as with Display Zoom off.
struct KeyboardDisplayZoom: Equatable {
    /// The factor the keyboard's heights are multiplied by: 1 without Display Zoom, below 1 with it.
    let heightScale: CGFloat

    static let none = KeyboardDisplayZoom(heightScale: 1)

    /// Reads the zoom from the screen: with Display Zoom on, the screen packs more of its own
    /// pixels into each point (`nativeScale`) than the pixels it draws each point with (`scale`).
    /// Capped at 1, as a screen that draws more pixels than it has without Display Zoom shows
    /// points smaller, not larger.
    static func resolve(for screen: UIScreen?) -> KeyboardDisplayZoom {
        guard let screen, screen.nativeScale > 0 else { return .none }
        return KeyboardDisplayZoom(heightScale: min(1, screen.scale / screen.nativeScale))
    }
}
