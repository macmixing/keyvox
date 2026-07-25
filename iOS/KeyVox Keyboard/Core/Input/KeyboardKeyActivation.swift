import UIKit

struct KeyboardKeyActivation {
    let kind: KeyboardKeyKind
    let location: CGPoint
    let timestamp: TimeInterval
    let isLongPressAlternate: Bool
}

struct KeyboardCharacterKeyGeometry: Equatable {
    let character: Character
    let frame: CGRect

    static func == (
        left: KeyboardCharacterKeyGeometry,
        right: KeyboardCharacterKeyGeometry
    ) -> Bool {
        left.character == right.character && left.frame.equalTo(right.frame)
    }
}
