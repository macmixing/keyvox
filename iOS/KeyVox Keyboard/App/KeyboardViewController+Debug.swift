import Foundation

#if DEBUG
extension KeyboardViewController {
    var debugHasHostLifecycleObservers: Bool {
        hostWillResignActiveObserver != nil && hostDidBecomeActiveObserver != nil
    }

    var debugIPCObserverRegistrationActive: Bool {
        ipcManager.debugIsRegistered
    }
}
#endif
