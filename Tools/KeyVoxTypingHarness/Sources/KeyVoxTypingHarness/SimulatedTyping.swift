import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// One word typed by a simulated finger: each intended letter is tapped at its key
/// center plus Gaussian noise, and the key nearest each tap becomes the typed letter.
///
/// Apostrophes are not tapped, matching how people type contractions on a letter
/// page and rely on autocorrect to restore them.
struct SimulatedTyping {
    let typedWord: String
    let touches: [PredictionTouch]

    init(
        intendedWord: String,
        layout: KeyboardLayoutModel,
        noiseStandardDeviation: Double,
        generator: inout SeededRandomGenerator
    ) {
        var typed = ""
        var touches: [PredictionTouch] = []
        for letter in intendedWord where letter != "'" {
            guard let center = layout.center(of: letter) else { continue }
            let offset = Self.gaussianPair(
                standardDeviation: noiseStandardDeviation,
                generator: &generator
            )
            let touch = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
            typed.append(layout.letter(at: touch))
            touches.append(PredictionTouch(location: touch))
        }
        typedWord = typed
        self.touches = touches
    }

    private static func gaussianPair(
        standardDeviation: Double,
        generator: inout SeededRandomGenerator
    ) -> CGPoint {
        guard standardDeviation > 0 else { return .zero }
        let first = Double.random(in: Double.leastNonzeroMagnitude..<1, using: &generator)
        let second = Double.random(in: 0..<1, using: &generator)
        let radius = (-2 * log(first)).squareRoot() * standardDeviation
        let angle = 2 * Double.pi * second
        return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
    }
}
