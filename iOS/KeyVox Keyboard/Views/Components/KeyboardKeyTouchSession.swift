import UIKit

/// One finger on the key grid: the key it is on and where it counts as having typed.
final class KeyboardKeyTouchSession {
    var keyView: KeyboardKeyView?
    /// Where the finger landed on its current key; this is the location typed.
    var activationLocation: CGPoint
    var timestamp: TimeInterval
    /// A character already typed because another finger landed first (rollover).
    var hasTyped = false

    init(keyView: KeyboardKeyView?, location: CGPoint, timestamp: TimeInterval) {
        self.keyView = keyView
        activationLocation = location
        self.timestamp = timestamp
    }

    var kind: KeyboardKeyKind? {
        keyView?.model.kind
    }

    var isPendingCharacter: Bool {
        guard hasTyped == false, case .character = kind else { return false }
        return true
    }
}
