import Foundation

nonisolated struct MacTriggerTapClassifier {
    enum Event: Equatable {
        case none
        case scheduleSingleTap
        case doubleTap
    }

    let doubleTapInterval: TimeInterval
    private var lastTapAt: Date?

    init(doubleTapInterval: TimeInterval = 0.28) {
        self.doubleTapInterval = doubleTapInterval
    }

    mutating func registerQuickTap(at date: Date) -> Event {
        guard let lastTapAt else {
            self.lastTapAt = date
            return .scheduleSingleTap
        }

        if date.timeIntervalSince(lastTapAt) <= doubleTapInterval {
            self.lastTapAt = nil
            return .doubleTap
        }

        self.lastTapAt = date
        return .scheduleSingleTap
    }
}
