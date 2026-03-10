import CoreGraphics
import Foundation

nonisolated struct KeyboardSpaceTrackpadConfiguration {
    var activationHoldDuration: TimeInterval = 0.35
    var horizontalStepDistance: CGFloat = 9
}

nonisolated enum KeyboardSpaceTrackpadPhase: Equatable {
    case inactive
    case armed
    case active
}

nonisolated struct KeyboardSpaceTrackpadUpdate {
    let activated: Bool
    let movementDelta: CGPoint?
}

nonisolated struct KeyboardSpaceTrackpadSession {
    private(set) var phase: KeyboardSpaceTrackpadPhase = .inactive

    private let configuration: KeyboardSpaceTrackpadConfiguration
    private var startedOnSpace = false
    private var startTimestamp: TimeInterval = 0
    private var lastTrackedLocation: CGPoint = .zero

    init(configuration: KeyboardSpaceTrackpadConfiguration = KeyboardSpaceTrackpadConfiguration()) {
        self.configuration = configuration
    }

    var isActive: Bool {
        phase == .active
    }

    mutating func begin(onSpaceKey: Bool, location: CGPoint, timestamp: TimeInterval) {
        startedOnSpace = onSpaceKey
        startTimestamp = timestamp
        lastTrackedLocation = location
        phase = onSpaceKey ? .armed : .inactive
    }

    mutating func update(location: CGPoint, timestamp: TimeInterval, isStillOnSpaceKey: Bool) -> KeyboardSpaceTrackpadUpdate {
        switch phase {
        case .inactive:
            return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: nil)
        case .armed:
            guard startedOnSpace, isStillOnSpaceKey else {
                reset()
                return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: nil)
            }

            guard timestamp - startTimestamp >= configuration.activationHoldDuration else {
                return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: nil)
            }

            phase = .active
            lastTrackedLocation = location
            return KeyboardSpaceTrackpadUpdate(activated: true, movementDelta: nil)
        case .active:
            let delta = CGPoint(x: location.x - lastTrackedLocation.x, y: location.y - lastTrackedLocation.y)
            lastTrackedLocation = location
            return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: delta)
        }
    }

    mutating func end() -> Bool {
        let wasActive = isActive
        reset()
        return wasActive
    }

    mutating func cancel() {
        reset()
    }

    private mutating func reset() {
        phase = .inactive
        startedOnSpace = false
        startTimestamp = 0
        lastTrackedLocation = .zero
    }
}

nonisolated struct KeyboardCursorTrackpadAccumulator {
    private let configuration: KeyboardSpaceTrackpadConfiguration
    private var horizontalRemainder: CGFloat = 0

    init(configuration: KeyboardSpaceTrackpadConfiguration = KeyboardSpaceTrackpadConfiguration()) {
        self.configuration = configuration
    }

    mutating func consume(delta: CGPoint) -> Int {
        horizontalRemainder += delta.x
        let stepCount = Int(horizontalRemainder / configuration.horizontalStepDistance)
        guard stepCount != 0 else { return 0 }

        horizontalRemainder -= configuration.horizontalStepDistance * CGFloat(stepCount)
        return stepCount
    }

    mutating func reset() {
        horizontalRemainder = 0
    }
}

nonisolated struct KeyboardCursorTrackpadInteractor {
    private var accumulator: KeyboardCursorTrackpadAccumulator

    init(configuration: KeyboardSpaceTrackpadConfiguration = KeyboardSpaceTrackpadConfiguration()) {
        accumulator = KeyboardCursorTrackpadAccumulator(configuration: configuration)
    }

    mutating func begin() {
        accumulator.reset()
    }

    mutating func handleMovement(delta: CGPoint, adjustCursor: (Int) -> Void) {
        let offset = accumulator.consume(delta: delta)
        guard offset != 0 else { return }
        adjustCursor(offset)
    }

    mutating func end() {
        accumulator.reset()
    }
}
