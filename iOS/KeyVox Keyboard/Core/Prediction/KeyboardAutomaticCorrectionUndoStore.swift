import Foundation

final class KeyboardAutomaticCorrectionUndoStore {
    private struct Correction {
        let original: String
        let replacement: String
    }

    private var correction: Correction?

    func record(original: String, replacement: String) {
        correction = Correction(original: original, replacement: replacement)
    }

    func consumeUndoIfAvailable(
        documentContextBeforeInput: String?,
        restore: (_ original: String, _ replacement: String) -> Bool
    ) -> Bool {
        guard let correction,
              documentContextBeforeInput?.hasSuffix(correction.replacement + " ") == true else {
            self.correction = nil
            return false
        }
        self.correction = nil
        return restore(correction.original, correction.replacement)
    }

    func invalidate() {
        correction = nil
    }
}
