import CoreHaptics

/// Plays the tap felt on a letter or character key through a Core Haptics engine of its own,
/// run the way the system keyboard runs its own: everything the engine does happens on a queue
/// of its own, so starting it never holds up the keys, and it stops after five seconds without
/// a tap and starts again with the next one.
final class KeyboardTextInputHapticPlayer: KeyboardImpactFeedbackGenerating {
    /// How long the engine keeps running after the last tap, as the system keyboard's does.
    static let idleStopDelay: TimeInterval = 5

    private let queue = DispatchQueue(label: "org.keyvox.keyboard.text-input-haptics", qos: .userInteractive)

    // Owned by `queue`.
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private var isRunning = false
    private var idleStop: DispatchWorkItem?

    func prepare() {
        queue.async { [weak self] in
            self?.startEngineIfNeeded()
        }
    }

    func impactOccurred() {
        queue.async { [weak self] in
            self?.play()
        }
    }

    private func play() {
        guard startEngineIfNeeded(), let engine else { return }
        if startPlayer(on: engine) == false {
            // The system stopped the engine without telling us in time: start it again and give
            // the tap one more try.
            isRunning = false
            player = nil
            guard startEngineIfNeeded() else { return }
            _ = startPlayer(on: engine)
        }
    }

    /// Starts the engine, creating it the first time, unless it is running, and schedules it to
    /// stop when no tap follows. Returns whether it is running.
    @discardableResult
    private func startEngineIfNeeded() -> Bool {
        if engine == nil {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
                  let engine = try? CHHapticEngine() else { return false }
            engine.playsHapticsOnly = true
            engine.stoppedHandler = { [weak self] _ in
                self?.queue.async {
                    self?.isRunning = false
                }
            }
            engine.resetHandler = { [weak self] in
                self?.queue.async {
                    self?.isRunning = false
                    self?.player = nil
                }
            }
            self.engine = engine
        }
        if isRunning == false {
            guard (try? engine?.start()) != nil else { return false }
            isRunning = true
        }
        scheduleIdleStop()
        return true
    }

    private func scheduleIdleStop() {
        idleStop?.cancel()
        let stop = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.isRunning = false
            self.engine?.stop(completionHandler: nil)
        }
        idleStop = stop
        queue.asyncAfter(deadline: .now() + Self.idleStopDelay, execute: stop)
    }

    private func startPlayer(on engine: CHHapticEngine) -> Bool {
        do {
            if player == nil {
                player = try engine.makePlayer(with: KeyboardTextInputHapticPattern.make())
            }
            try player?.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }
}
