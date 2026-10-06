import UIKit

/// A key the user typed, with where the finger was when it counted and the key's frame,
/// in key-grid points.
struct KeyboardKeyActivation: Equatable {
    let kind: KeyboardKeyKind
    let location: CGPoint
    let keyFrame: CGRect
    let timestamp: TimeInterval
    /// Whether a held key is repeating rather than being freshly pressed.
    let isRepeat: Bool
}

/// A letter key's frame in key-grid points, reported for the prediction engine.
struct KeyboardCharacterKeyGeometry: Equatable {
    let character: Character
    let frame: CGRect
}
