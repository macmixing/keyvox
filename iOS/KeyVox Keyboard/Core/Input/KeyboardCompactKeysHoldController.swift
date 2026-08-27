import Foundation

final class KeyboardCompactKeysHoldController {
    private let activationHoldDuration: TimeInterval
    private var activationTimer: Timer?
    private var activationHandler: (() -> Bool)?
    private var didActivate = false

    init(activationHoldDuration: TimeInterval = 0.5) {
        self.activationHoldDuration = activationHoldDuration
    }

    func begin(onCompactKeysTrigger: Bool, onActivate: @escaping () -> Bool) {
        cancel()
        guard onCompactKeysTrigger else { return }

        activationHandler = onActivate
        let timer = Timer(timeInterval: activationHoldDuration, repeats: false) { [weak self] _ in
            self?.activateIfNeeded()
        }
        activationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func update(isStillOnCompactKeysTrigger: Bool) {
        guard isStillOnCompactKeysTrigger == false, didActivate == false else { return }
        invalidatePendingActivation()
    }

    func end() -> Bool {
        let activated = didActivate
        cancel()
        return activated
    }

    func cancel() {
        activationTimer?.invalidate()
        activationTimer = nil
        activationHandler = nil
        didActivate = false
    }

    private func activateIfNeeded() {
        activationTimer = nil
        guard let activationHandler else { return }
        didActivate = activationHandler()
        self.activationHandler = nil
    }

    private func invalidatePendingActivation() {
        activationTimer?.invalidate()
        activationTimer = nil
        activationHandler = nil
    }
}
