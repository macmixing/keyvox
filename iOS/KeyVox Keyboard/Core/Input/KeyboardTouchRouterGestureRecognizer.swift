import UIKit

final class KeyboardTouchRouterGestureRecognizer: UIGestureRecognizer {
    var onTouchesBegan: ((Set<UITouch>, UIEvent) -> Void)?
    var onTouchesMoved: ((Set<UITouch>, UIEvent) -> Void)?
    var onTouchesEnded: ((Set<UITouch>, UIEvent) -> Void)?
    var onTouchesCancelled: ((Set<UITouch>, UIEvent) -> Void)?

    private var activeTouches = Set<ObjectIdentifier>()

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouches.formUnion(touches.map(ObjectIdentifier.init))
        onTouchesBegan?(touches, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchesMoved?(touches, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchesEnded?(touches, event)
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouchesCancelled?(touches, event)
        finish(touches)
    }

    override func reset() {
        activeTouches.removeAll()
        super.reset()
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    private func finish(_ touches: Set<UITouch>) {
        activeTouches.subtract(touches.map(ObjectIdentifier.init))
        if activeTouches.isEmpty {
            state = .failed
        }
    }
}
