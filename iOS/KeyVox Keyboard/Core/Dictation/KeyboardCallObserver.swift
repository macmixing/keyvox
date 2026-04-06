import CallKit
import Foundation

final class KeyboardCallObserver: NSObject, CXCallObserverDelegate {
    var onCallStateChange: (() -> Void)?

    private let callObserver: CXCallObserver
    private(set) var hasActivePhoneCall = false {
        didSet {
            guard oldValue != hasActivePhoneCall else { return }
            onCallStateChange?()
        }
    }

    init(callObserver: CXCallObserver = CXCallObserver()) {
        self.callObserver = callObserver
        super.init()
        callObserver.setDelegate(self, queue: .main)
        refreshState()
    }

    func refreshState() {
        hasActivePhoneCall = callObserver.calls.contains(where: { $0.hasEnded == false })
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged _: CXCall) {
        refreshState()
    }
}
