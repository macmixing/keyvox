import CoreGraphics
import Foundation

enum KeyboardSpaceTrackpadEvent {
    case began
    case moved(CGPoint)
    case ended
    case cancelled
}

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
    private var action: (() -> Void)?
    private var delayTimer: Timer?
    private var repeatTimer: Timer?

    func begin(action: @escaping () -> Void) {
        cancel()
        self.action = action
        action()
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
            self?.action?()
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
