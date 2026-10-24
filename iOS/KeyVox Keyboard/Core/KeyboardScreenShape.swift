import UIKit

/// Whether the screen the keyboard is on is wider than it is tall, read from the space the
/// keyboard's scene has rather than from the interface orientation, which on iPhone Duo does not
/// tell an app what shape it is.
enum KeyboardScreenShape {
    static func isWide(_ view: UIView) -> Bool {
        guard let bounds = view.window?.windowScene?.coordinateSpace.bounds else { return false }
        return bounds.width > bounds.height
    }
}
