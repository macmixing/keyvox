import CoreGraphics
import Foundation

enum KeyboardSpaceTrackpadEvent {
    case began
    case moved(CGPoint, timestamp: TimeInterval)
    case ended
    case cancelled
}

nonisolated struct KeyboardSpaceTrackpadConfiguration {
    var activationHoldDuration: TimeInterval
    var horizontalStepDistance: CGFloat
    var activationMovementTolerance: CGFloat
    var minimumCursorVelocityMultiplier: CGFloat
    var maximumCursorVelocityMultiplier: CGFloat
    var minimumCursorAccelerationVelocity: CGFloat
    var maximumCursorAccelerationVelocity: CGFloat
    var cursorVelocitySamplingFloor: TimeInterval

    init(
        activationHoldDuration: TimeInterval = 0.35,
        horizontalStepDistance: CGFloat = 9,
        activationMovementTolerance: CGFloat = 8,
        minimumCursorVelocityMultiplier: CGFloat = 0.65,
        maximumCursorVelocityMultiplier: CGFloat = 5,
        minimumCursorAccelerationVelocity: CGFloat = 70,
        maximumCursorAccelerationVelocity: CGFloat = 520,
        cursorVelocitySamplingFloor: TimeInterval = 1.0 / 240.0
    ) {
        self.activationHoldDuration = activationHoldDuration
        self.horizontalStepDistance = horizontalStepDistance
        self.activationMovementTolerance = activationMovementTolerance
        self.minimumCursorVelocityMultiplier = minimumCursorVelocityMultiplier
        self.maximumCursorVelocityMultiplier = maximumCursorVelocityMultiplier
        self.minimumCursorAccelerationVelocity = minimumCursorAccelerationVelocity
        self.maximumCursorAccelerationVelocity = maximumCursorAccelerationVelocity
        self.cursorVelocitySamplingFloor = cursorVelocitySamplingFloor
    }

    func cursorVelocityMultiplier(forHorizontalVelocity horizontalVelocity: CGFloat) -> CGFloat {
        let velocityRange = maximumCursorAccelerationVelocity - minimumCursorAccelerationVelocity
        guard velocityRange > 0 else {
            return maximumCursorVelocityMultiplier
        }

        let normalizedVelocity = min(
            max(
                (horizontalVelocity - minimumCursorAccelerationVelocity) / velocityRange,
                0
            ),
            1
        )
        let multiplierRange = maximumCursorVelocityMultiplier - minimumCursorVelocityMultiplier
        return minimumCursorVelocityMultiplier + (multiplierRange * normalizedVelocity)
    }
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
    private var startLocation: CGPoint = .zero
    private var lastTrackedLocation: CGPoint = .zero

    init(configuration: KeyboardSpaceTrackpadConfiguration = KeyboardSpaceTrackpadConfiguration()) {
        self.configuration = configuration
    }

    var isActive: Bool {
        phase == .active
    }

    mutating func begin(onSpaceKey: Bool, location: CGPoint) {
        startedOnSpace = onSpaceKey
        startLocation = location
        lastTrackedLocation = location
        phase = onSpaceKey ? .armed : .inactive
    }

    mutating func update(location: CGPoint, isStillOnSpaceKey: Bool) -> KeyboardSpaceTrackpadUpdate {
        switch phase {
        case .inactive:
            return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: nil)
        case .armed:
            guard startedOnSpace, isStillOnSpaceKey else {
                reset()
                return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: nil)
            }

            let preActivationDelta = CGPoint(
                x: location.x - startLocation.x,
                y: location.y - startLocation.y
            )
            let preActivationDistance = hypot(preActivationDelta.x, preActivationDelta.y)
            guard preActivationDistance <= configuration.activationMovementTolerance else {
                reset()
                return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: nil)
            }
            lastTrackedLocation = location
            return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: nil)
        case .active:
            let delta = CGPoint(x: location.x - lastTrackedLocation.x, y: location.y - lastTrackedLocation.y)
            lastTrackedLocation = location
            return KeyboardSpaceTrackpadUpdate(activated: false, movementDelta: delta)
        }
    }

    mutating func activate(location: CGPoint) -> Bool {
        guard phase == .armed, startedOnSpace else { return false }
        phase = .active
        lastTrackedLocation = location
        return true
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
        startLocation = .zero
        lastTrackedLocation = .zero
    }
}

final class KeyboardSpaceTrackpadController {
    private var session: KeyboardSpaceTrackpadSession
    private let activationHoldDuration: TimeInterval
    private var activationTimer: Timer?
    private var currentLocation: CGPoint = .zero
    private var activationHandler: (() -> Void)?

    init(configuration: KeyboardSpaceTrackpadConfiguration = KeyboardSpaceTrackpadConfiguration()) {
        session = KeyboardSpaceTrackpadSession(configuration: configuration)
        activationHoldDuration = configuration.activationHoldDuration
    }

    var isActive: Bool {
        session.isActive
    }

    func begin(onSpaceKey: Bool, location: CGPoint, onActivate: @escaping () -> Void) {
        cancelTimer()
        currentLocation = location
        activationHandler = onSpaceKey ? onActivate : nil
        session.begin(onSpaceKey: onSpaceKey, location: location)

        guard onSpaceKey else { return }
        let timer = Timer(timeInterval: activationHoldDuration, repeats: false) { [weak self] _ in
            self?.activateIfNeeded()
        }
        activationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func update(location: CGPoint, isStillOnSpaceKey: Bool) -> KeyboardSpaceTrackpadUpdate {
        currentLocation = location
        return session.update(location: location, isStillOnSpaceKey: isStillOnSpaceKey)
    }

    func end() -> Bool {
        cancelTimer()
        activationHandler = nil
        return session.end()
    }

    func cancel() -> Bool {
        cancelTimer()
        activationHandler = nil
        let wasActive = session.isActive
        session.cancel()
        return wasActive
    }

    private func activateIfNeeded() {
        guard session.activate(location: currentLocation) else { return }
        activationHandler?()
    }

    private func cancelTimer() {
        activationTimer?.invalidate()
        activationTimer = nil
    }
}

/// Repeats a held delete key on `KeyboardDeleteRepeatSchedule` until it is released or
/// there is nothing left to delete. Each repeat is due a set time after the one before it was
/// due, so the time each deletion takes never slows the pace.
final class KeyboardDeleteRepeatController {
    private var action: ((KeyboardDeleteGranularity) -> Bool)?
    private var repeatCount = 0
    private var nextRepeatDate = Date()
    private var timer: Timer?

    /// Deletes a character now, then repeats on the schedule while `action` keeps deleting.
    func begin(action: @escaping (KeyboardDeleteGranularity) -> Bool) {
        cancel()
        self.action = action
        nextRepeatDate = Date()
        guard action(.character) else {
            cancel()
            return
        }
        scheduleNextRepeat()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        action = nil
        repeatCount = 0
    }

    private func scheduleNextRepeat() {
        nextRepeatDate += KeyboardDeleteRepeatSchedule.delay(beforeRepeat: repeatCount)
        let timer = Timer(fire: nextRepeatDate, interval: 0, repeats: false) { [weak self] _ in
            self?.performRepeat()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func performRepeat() {
        let granularity = KeyboardDeleteRepeatSchedule.granularity(ofRepeat: repeatCount)
        guard action?(granularity) == true else {
            cancel()
            return
        }
        repeatCount += 1
        scheduleNextRepeat()
    }
}
