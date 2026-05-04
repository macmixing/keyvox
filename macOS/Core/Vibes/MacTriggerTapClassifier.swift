import Foundation

struct MacTriggerTapClassifier {
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
        defer { lastTapAt = date }

        guard let lastTapAt else {
            return .scheduleSingleTap
        }

        if date.timeIntervalSince(lastTapAt) <= doubleTapInterval {
            self.lastTapAt = nil
            return .doubleTap
        }

        return .scheduleSingleTap
    }
}
