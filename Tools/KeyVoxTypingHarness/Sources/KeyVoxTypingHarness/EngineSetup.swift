import Foundation
import KeyVoxPredictiveKeyboard

/// The engine, sized to the harness keyboard grid, plus how long it took to start.
struct EngineSetup {
    let engine: EnglishPredictiveEngine
    let layout: KeyboardLayoutModel
    let keys: KeyCenterMap
    let language: ContextLanguageScorer
    let startupMilliseconds: Double
    /// Physical footprint the engine added when it loaded.
    let startupFootprintBytes: UInt64

    init() throws {
        let footprintBefore = MemoryFootprint.current()
        let started = ContinuousClock.now
        engine = try EnglishPredictiveEngine()
        layout = KeyboardLayoutModel()
        engine.updateKeyboardGeometry(layout.predictionGeometry, keyboardSize: layout.keyboardSize)
        startupMilliseconds = Self.milliseconds(since: started)
        startupFootprintBytes = MemoryFootprint.current() &- footprintBefore
        keys = KeyCenterMap(geometry: layout.predictionGeometry)
        language = ContextLanguageScorer(engine: engine)
    }

    func correctionEvaluator(decider: CorrectionEvaluator.Decider) -> CorrectionEvaluator {
        CorrectionEvaluator(engine: engine, decider: decider, keys: keys, language: language)
    }

    static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1e15
    }
}
