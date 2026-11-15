import UIKit

/// The kind of display the keyboard is on, for the key sizes that differ between them.
enum KeyboardDisplay: Equatable {
    /// An iPhone display, or an iPad's floating keyboard.
    case standard
    /// The large inner display of an open foldable iPhone.
    case openFoldable
    /// A full-width keyboard on iPad.
    case pad

    /// Whether a numbers-only field shows the number pad: everywhere but the full-width iPad
    /// keyboard, where the system's keyboard opens such a field on its full keyboard's numbers page
    /// upright and on its side, while its floating keyboard shows the number pad, as on iOS 27.
    var showsNumberPad: Bool {
        self != .pad
    }

    /// Reads the display from the keyboard's traits: an iPad and an open foldable's inner display
    /// are both regular in width and height, and only the iPad has the pad idiom.
    static func resolve(in traits: UITraitCollection) -> KeyboardDisplay {
        guard KeyboardFoldableDisplay.isOpen(in: traits) else { return .standard }
        return traits.userInterfaceIdiom == .pad ? .pad : .openFoldable
    }
}
