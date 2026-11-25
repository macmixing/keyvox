import KeyVoxPredictiveKeyboard
import UIKit

/// One finger on the key grid: the key it is on and where it counts as having typed.
final class KeyboardKeyTouchSession {
    var keyView: KeyboardKeyView?
    /// Where the finger landed on its current key; this is the location typed.
    var activationLocation: CGPoint
    /// Where the finger is now.
    var location: CGPoint
    var timestamp: TimeInterval
    /// A character already typed because another finger landed first (rollover).
    var hasTyped = false
    /// Every sample of the finger since it landed, kept while the swipe gate may still make it a
    /// swipe and once it has; empty for a finger that can never swipe.
    var swipePath: [SwipeTouchSample] = []
    /// The finger is swiping: it types nothing as a key, and its path is the word.
    var isSwipe = false

    init(keyView: KeyboardKeyView?, location: CGPoint, timestamp: TimeInterval) {
        self.keyView = keyView
        activationLocation = location
        self.location = location
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
