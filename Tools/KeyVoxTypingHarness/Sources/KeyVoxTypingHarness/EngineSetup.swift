import Foundation
import KeyVoxPredictiveKeyboard

/// The engine, sized to the harness keyboard grid, plus how long it took to start.
struct EngineSetup {
    let engine: PredictiveEngine
    let layout: KeyboardLayoutModel
    let keys: KeyCenterMap
    let language: ContextLanguageScorer
    let startupMilliseconds: Double
    /// Physical footprint the engine added when it loaded.
    let startupFootprintBytes: UInt64

    /// - Parameter languageIdentifier: The bundled typing language to load, by its folder name.
    init(languageIdentifier: String = "en") throws {
        let footprintBefore = MemoryFootprint.current()
        let started = ContinuousClock.now
        engine = try PredictiveEngine(language: TypingLanguage.bundled(identifier: languageIdentifier))
        layout = KeyboardLayoutModel()
        engine.updateKeyboardGeometry(layout.predictionGeometry, keyboardSize: layout.keyboardSize)
        startupMilliseconds = Self.milliseconds(since: started)
        startupFootprintBytes = MemoryFootprint.current() &- footprintBefore
        keys = KeyCenterMap(geometry: layout.predictionGeometry)
        language = ContextLanguageScorer(engine: engine)
    }

    func correctionEvaluator(parameters: NoisyChannelCorrector.Parameters) -> CorrectionEvaluator {
        CorrectionEvaluator(engine: engine, parameters: parameters, keys: keys, language: language)
    }

    static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000
            + Double(elapsed.components.attoseconds) / 1e15
    }
}
