import CoreGraphics
import Foundation

enum KeyboardSpaceTrackpadEvent {
    case began
    case moved(CGPoint)
    case ended
    case cancelled
}

nonisolated struct KeyboardSpaceTrackpadConfiguration {
    var activationHoldDuration: TimeInterval
    var horizontalStepDistance: CGFloat
    var activationMovementTolerance: CGFloat

    init(
        activationHoldDuration: TimeInterval = 0.35,
        horizontalStepDistance: CGFloat = 9,
        activationMovementTolerance: CGFloat = 8
    ) {
        self.activationHoldDuration = activationHoldDuration
        self.horizontalStepDistance = horizontalStepDistance
        self.activationMovementTolerance = activationMovementTolerance
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

final class KeyboardDeleteRepeatController {
    private enum State {
        case inactive
        case paused
        case delaying
        case repeating
    }

    private let initialDelay: TimeInterval = 0.42
    private let repeatInterval: TimeInterval = 0.085

    private var state: State = .inactive
    private var action: (() -> Bool)?
    private var delayTimer: Timer?
    private var repeatTimer: Timer?

    func begin(action: @escaping () -> Bool) {
        cancel()
        self.action = action
        guard action() else {
            cancel()
            return
        }
        scheduleInitialDelay()
    }

    func pause() {
        guard state == .delaying || state == .repeating else { return }
        invalidateTimers()
        state = .paused
    }

    func resumeIfNeeded() {
        guard state == .paused, action != nil else { return }
        scheduleInitialDelay()
    }

    func cancel() {
        invalidateTimers()
        action = nil
        state = .inactive
    }

    private func scheduleInitialDelay() {
        invalidateTimers()
        state = .delaying
        let timer = Timer(timeInterval: initialDelay, repeats: false) { [weak self] _ in
            self?.startRepeating()
        }
        delayTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startRepeating() {
        guard action != nil else {
            cancel()
            return
        }

        invalidateTimers()
        state = .repeating
        let timer = Timer(timeInterval: repeatInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.action?() == true else {
                self.cancel()
                return
            }
        }
        repeatTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func invalidateTimers() {
        delayTimer?.invalidate()
        repeatTimer?.invalidate()
        delayTimer = nil
        repeatTimer = nil
    }
}
