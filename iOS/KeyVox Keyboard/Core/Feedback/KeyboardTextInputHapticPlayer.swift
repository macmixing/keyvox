import CoreHaptics

/// Plays the tap felt on a letter or character key through a Core Haptics engine of its own,
/// as the system keyboard does, rather than through the shared feedback generators. The engine
/// starts when the keyboard prepares it, shuts itself down when typing stops, and starts again
/// with the next tap.
final class KeyboardTextInputHapticPlayer: KeyboardImpactFeedbackGenerating {
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    func prepare() {
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in
                self?.player = nil
                try? self?.engine?.start()
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func impactOccurred() {
        prepare()
        guard let engine else { return }
        if play(on: engine) == false {
            // The engine had stopped, as it does when the keyboard goes idle or the system
            // interrupts it: start it again and give the tap one more try.
            player = nil
            try? engine.start()
            _ = play(on: engine)
        }
    }

    private func play(on engine: CHHapticEngine) -> Bool {
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
