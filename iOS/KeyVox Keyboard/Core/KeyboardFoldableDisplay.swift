import UIKit

/// Whether the keyboard is on the large inner display of an open foldable iPhone, partially or
/// fully open.
///
/// Workaround for the current iPhone Duo situation: a keyboard extension never receives hinge
/// updates (`UIHingeInteraction` never calls its handler there; FB25308064), so the open state is
/// inferred from the display instead. The open inner display is the only iPhone display that is
/// regular in both width and height; every other iPhone display has a compact side in either
/// orientation. Partially and fully open look the same from a keyboard. Replace this with the
/// hinge state once keyboard extensions receive it.
enum KeyboardFoldableDisplay {
    static func isOpen(in traits: UITraitCollection) -> Bool {
        traits.userInterfaceIdiom == .phone
            && traits.horizontalSizeClass == .regular
            && traits.verticalSizeClass == .regular
    }
}
