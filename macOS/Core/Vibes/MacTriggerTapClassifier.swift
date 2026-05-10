import Foundation

nonisolated struct MacTriggerTapClassifier {
    enum Event: Equatable {
        case none
        case scheduleSingleTap
        case doubleTap
    }

    let doubleTapInterval: TimeInterval
    private var lastTapAt: TimeInterval?

    init(doubleTapInterval: TimeInterval = 0.85) {
        self.doubleTapInterval = doubleTapInterval
    }

    mutating func registerQuickTap(at timestamp: TimeInterval) -> Event {
        guard let lastTapAt else {
            self.lastTapAt = timestamp
            return .scheduleSingleTap
        }

        if timestamp - lastTapAt <= doubleTapInterval {
            self.lastTapAt = nil
            return .doubleTap
        }

        self.lastTapAt = timestamp
        return .scheduleSingleTap
    }
}
