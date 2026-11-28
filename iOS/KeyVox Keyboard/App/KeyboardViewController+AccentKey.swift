import KeyVoxPredictiveKeyboard
import UIKit

/// The accent key some letter layouts draw beside the letters, in a typing language that drives
/// it: it shows and types the mark the language's accent key puts on the letter before the cursor,
/// the apostrophe, or its own character, as on the system keyboard (`AccentKey`).
extension KeyboardViewController {
    /// Shows on the accent key what it types after the text as it is now: the letter's usual mark
    /// at once, then, where predictions run, the mark the dictionary's words choose.
    func updateAccentKey() {
        guard let accentKey = KeyboardTypingLanguage.current.accentKey else {
            rootContainerView?.keyGridView.setAccentKeyLabel(nil)
            return
        }
        let mark = accentKey.mark(after: textDocumentProxy.documentContextBeforeInput)
        rootContainerView?.keyGridView.setAccentKeyLabel(KeyboardAccentKeyLabel(character: accentKey.character, mark: mark))
        guard typingTraits.allowsPredictions else { return }
        predictionCoordinator.accentKeyMark { [weak self] mark in
            self?.rootContainerView?.keyGridView.setAccentKeyLabel(
                KeyboardAccentKeyLabel(character: accentKey.character, mark: mark)
            )
        }
    }

    /// Puts `mark`, typed with the accent key or picked from its popup, on the letter before the
    /// cursor. Returns nil when no letter there takes it, for the regular path to type the mark.
    func applyAccentMark(_ mark: String) -> Bool? {
        guard let accentKey = KeyboardTypingLanguage.current.accentKey,
              let edit = accentKey.edit(placing: mark, after: textDocumentProxy.documentContextBeforeInput) else {
            return nil
        }
        textInputController.apply(edit)
        handleTypingContextChange()
        return true
    }
}
