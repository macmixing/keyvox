import Foundation
import KeyVoxPredictiveKeyboard

/// The engine, sized to the harness keyboard grid, plus how long it took to start.
struct EngineSetup {
    let engine: EnglishPredictiveEngine
    let layout: KeyboardLayoutModel
    let startupMilliseconds: Double

    init() throws {
        let started = ContinuousClock.now
        engine = try EnglishPredictiveEngine()
        layout = KeyboardLayoutModel()
        engine.updateKeyboardGeometry(layout.predictionGeometry, keyboardSize: layout.keyboardSize)
        startupMilliseconds = Self.milliseconds(since: started)
    }

    static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1e15
    }
}
