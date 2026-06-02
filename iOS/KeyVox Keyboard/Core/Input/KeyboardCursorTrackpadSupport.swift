import CoreGraphics
import Foundation

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
    private let configuration: KeyboardSpaceTrackpadConfiguration
    private var accumulator: KeyboardCursorTrackpadAccumulator
    private var lastMovementTimestamp: TimeInterval?

    init(configuration: KeyboardSpaceTrackpadConfiguration = KeyboardSpaceTrackpadConfiguration()) {
        self.configuration = configuration
        accumulator = KeyboardCursorTrackpadAccumulator(configuration: configuration)
    }

    mutating func begin() {
        lastMovementTimestamp = nil
        accumulator.reset()
    }

    mutating func handleMovement(
        delta: CGPoint,
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime,
        adjustCursor: (Int) -> Void
    ) {
        let velocityMultiplier = cursorVelocityMultiplier(for: delta, timestamp: timestamp)
        let acceleratedDelta = CGPoint(x: delta.x * velocityMultiplier, y: delta.y)
        let offset = accumulator.consume(delta: acceleratedDelta)
        guard offset != 0 else { return }
        adjustCursor(offset)
    }

    mutating func end() {
        lastMovementTimestamp = nil
        accumulator.reset()
    }

    private mutating func cursorVelocityMultiplier(for delta: CGPoint, timestamp: TimeInterval) -> CGFloat {
        defer {
            lastMovementTimestamp = timestamp
        }

        guard let lastMovementTimestamp else {
            return 1
        }

        let elapsedTime = max(timestamp - lastMovementTimestamp, configuration.cursorVelocitySamplingFloor)
        let horizontalVelocity = abs(delta.x) / elapsedTime
        return configuration.cursorVelocityMultiplier(forHorizontalVelocity: horizontalVelocity)
    }
}
