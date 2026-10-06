import UIKit

/// A key the user typed, with where the finger was when it counted, in key-grid points.
struct KeyboardKeyActivation: Equatable {
    let kind: KeyboardKeyKind
    let location: CGPoint
    let timestamp: TimeInterval
}

/// A letter key's frame in key-grid points, reported for the prediction engine.
struct KeyboardCharacterKeyGeometry: Equatable {
    let character: Character
    let frame: CGRect
}
