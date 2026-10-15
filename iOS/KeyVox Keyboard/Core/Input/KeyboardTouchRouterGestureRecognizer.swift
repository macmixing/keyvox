import UIKit

/// Forwards every raw touch on the key grid, for any number of fingers, without delaying
/// or cancelling them, so the grid can follow overlapping taps itself, with the event each came in.
final class KeyboardTouchRouterGestureRecognizer: UIGestureRecognizer {
    var onTouchesBegan: ((Set<UITouch>, UIEvent) -> Void)?
    var onTouchesMoved: ((Set<UITouch>, UIEvent) -> Void)?
    var onTouchesEnded: ((Set<UITouch>, UIEvent) -> Void)?
    var onTouchesCancelled: ((Set<UITouch>, UIEvent) -> Void)?

    private var activeTouchCount = 0

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouchCount += touches.count
        onTouchesBegan?(touches, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchesMoved?(touches, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchesEnded?(touches, event)
        finish(touches.count)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchesCancelled?(touches, event)
        finish(touches.count)
    }

    override func reset() {
        activeTouchCount = 0
        super.reset()
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    private func finish(_ count: Int) {
        activeTouchCount = max(0, activeTouchCount - count)
        if activeTouchCount == 0 {
            state = .failed
        }
    }
}
