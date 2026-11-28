import KeyVoxPredictiveKeyboard
import UIKit

/// The accent key some letter layouts draw beside the letters, in a typing language that drives
/// it: it shows and types the mark the language's accent key puts on the letter before the cursor,
/// the apostrophe, or its own character, as on the system keyboard (`AccentKey`), in the text the
/// keys type into: the emoji search's while it is open, the document's otherwise.
extension KeyboardViewController {
    /// The text before the cursor of what the keys type into.
    private var accentKeyText: String? {
        emojiPanel == .searching ? emojiSearchText : textDocumentProxy.documentContextBeforeInput
    }

    /// Shows on the accent key what it types after the text as it is now: the letter's usual mark
    /// at once, then, where predictions run, the mark the dictionary's words choose while the text
    /// is still that.
    func updateAccentKey() {
        guard let accentKey = KeyboardTypingLanguage.current.accentKey else {
            rootContainerView?.keyGridView.setAccentKeyLabel(nil)
            return
        }
        let text = accentKeyText
        let mark = accentKey.mark(after: text)
        rootContainerView?.keyGridView.setAccentKeyLabel(KeyboardAccentKeyLabel(character: accentKey.character, mark: mark))
        guard typingTraits.allowsPredictions else { return }
        predictionCoordinator.accentKeyMark(after: text) { [weak self] mark in
            guard let self, self.accentKeyText == text else { return }
            self.rootContainerView?.keyGridView.setAccentKeyLabel(
                KeyboardAccentKeyLabel(character: accentKey.character, mark: mark)
            )
        }
    }

    /// Puts `mark`, typed with the accent key or picked from its popup, on the letter before the
    /// cursor. Returns nil when no letter there takes it, for the regular path to type the mark.
    func applyAccentMark(_ mark: String) -> Bool? {
        guard let accentKey = KeyboardTypingLanguage.current.accentKey,
              let edit = accentKey.edit(placing: mark, after: accentKeyText) else {
            return nil
        }
        if emojiPanel == .searching {
            setEmojiSearchText(String(emojiSearchText.dropLast(edit.deleteCount)) + edit.insertText)
        } else {
            textInputController.apply(edit)
            handleTypingContextChange()
        }
        return true
    }
}
