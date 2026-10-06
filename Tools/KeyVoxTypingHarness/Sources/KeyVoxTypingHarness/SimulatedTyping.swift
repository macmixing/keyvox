import CoreGraphics
import KeyVoxPredictiveKeyboard

/// One word typed by a planned finger: each letter is tapped at its key center plus the
/// planned offset, and the key nearest each tap becomes the typed letter.
///
/// Apostrophes are not tapped, matching how people type contractions on a letter
/// page and rely on autocorrect to restore them.
struct SimulatedTyping {
    let typedWord: String
    let touches: [PredictionTouch]

    init(tappedWord: String, offsetsInKeyPitches: [[Double]], layout: KeyboardLayoutModel) {
        var typed = ""
        var touches: [PredictionTouch] = []
        for (letter, offset) in zip(tappedWord.filter { $0 != "'" }, offsetsInKeyPitches) {
            guard let center = layout.center(of: letter) else { continue }
            let touch = CGPoint(
                x: center.x + offset[0] * layout.keyPitch.width,
                y: center.y + offset[1] * layout.keyPitch.height
            )
            typed.append(layout.letter(at: touch))
            touches.append(PredictionTouch(location: touch))
        }
        typedWord = typed
        self.touches = touches
    }
}
