import UIKit

/// The kind of display the keyboard is on, for the key sizes that differ between them.
enum KeyboardDisplay: Equatable {
    /// An iPhone display, or an iPad's floating keyboard.
    case standard
    /// The large inner display of an open foldable iPhone.
    case openFoldable
    /// A full-width keyboard on iPad.
    case pad

    /// Reads the display from the keyboard's traits: an iPad and an open foldable's inner display
    /// are both regular in width and height, and only the iPad has the pad idiom.
    static func resolve(in traits: UITraitCollection) -> KeyboardDisplay {
        guard KeyboardFoldableDisplay.isOpen(in: traits) else { return .standard }
        return traits.userInterfaceIdiom == .pad ? .pad : .openFoldable
    }
}
