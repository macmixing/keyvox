import UIKit

#if DEBUG
private final class KeyboardTypingTouchProbeGestureRecognizer: UIGestureRecognizer {
    private var activeTouches = Set<ObjectIdentifier>()

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            activeTouches.insert(ObjectIdentifier(touch))
            let location = touch.location(in: view)
            KeyboardTypingDiagnostics.log("host_touch_begin", fields: [
                "x": diagnosticCoordinate(location.x),
                "y": diagnosticCoordinate(location.y),
                "event_timestamp_ms": Int((touch.timestamp * 1_000).rounded()),
                "delivery_delay_ms": diagnosticDuration(
                    from: touch.timestamp,
                    to: ProcessInfo.processInfo.systemUptime
                ),
                "target": touch.view.map { String(describing: type(of: $0)) } ?? "none",
                "active_touches": activeTouches.count,
            ])
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches, event: "host_touch_end")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches, event: "host_touch_cancel")
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

    private func finish(_ touches: Set<UITouch>, event: String) {
        for touch in touches {
            activeTouches.remove(ObjectIdentifier(touch))
            let location = touch.location(in: view)
            KeyboardTypingDiagnostics.log(event, fields: [
                "x": diagnosticCoordinate(location.x),
                "y": diagnosticCoordinate(location.y),
                "event_timestamp_ms": Int((touch.timestamp * 1_000).rounded()),
                "active_touches": activeTouches.count,
            ])
        }
        if activeTouches.isEmpty {
            state = .failed
        }
    }

    private func diagnosticCoordinate(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    private func diagnosticDuration(from start: TimeInterval, to end: TimeInterval) -> Double {
        ((end - start) * 100_000).rounded() / 100
    }
}

extension KeyboardViewController {
    func installDebugTypingTouchProbe() {
        view.addGestureRecognizer(
            KeyboardTypingTouchProbeGestureRecognizer(target: nil, action: nil)
        )
    }

    var debugHasPresentationViewTree: Bool {
        rootContainerView != nil && popupOverlayView != nil
    }

    var debugRootViewIdentifier: ObjectIdentifier? {
        rootContainerView.map(ObjectIdentifier.init)
    }

    var debugFullAccessViewIdentifier: ObjectIdentifier? {
        fullAccessView.map(ObjectIdentifier.init)
    }

    var debugHasHostLifecycleObservers: Bool {
        hostWillResignActiveObserver != nil && hostDidBecomeActiveObserver != nil
    }

    var debugIPCObserverRegistrationActive: Bool {
        ipcManager.debugIsRegistered
    }

    static func resetPresentationLifecycleDiagnostics() {
        KeyboardPresentationLifecycleDiagnostics.reset()
    }

    static var debugCreatedPresentationViewTreeCount: Int {
        KeyboardPresentationLifecycleDiagnostics.createdPresentationViewTreeCount
    }

    static var debugDestroyedPresentationViewTreeCount: Int {
        KeyboardPresentationLifecycleDiagnostics.destroyedPresentationViewTreeCount
    }

    func debugPresentFullAccessInstructionsForTesting() {
        setFullAccessInstructionsPresented(true)
    }
}
#endif
