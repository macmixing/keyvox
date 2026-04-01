import Foundation

#if DEBUG
extension KeyboardViewController {
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
