import CoreGraphics

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
