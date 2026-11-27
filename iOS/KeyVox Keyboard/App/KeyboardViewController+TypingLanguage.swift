import KeyVoxPredictiveKeyboard
import UIKit

/// The typing language: following the user's languages and layouts, and the one place a change of
/// language reaches the keys, predictions, swipes, taps, and what the keyboard learned.
extension KeyboardViewController {
    /// Rereads the user's typing languages, as each time the keyboard shows or its host comes back,
    /// and shows the language they give when it changed.
    func adoptTypingLanguageSettings() {
        let changed = KeyboardTypingLanguage.adoptSettings(appSettingsStore)
        rootContainerView?.keyGridView.allowsSpaceLanguageSlide = KeyboardTypingLanguage.selection.languages.count > 1
        guard changed else { return }
        applyTypingLanguage()
    }

    /// Switches to the selected language `offset` places from the current one, as a slide across
    /// the space bar asks: a light haptic, the keyboard in the new language, and its short code on
    /// the space bar for a moment.
    func switchTypingLanguage(by offset: Int) {
        guard KeyboardTypingLanguage.switchLanguage(by: offset, settings: appSettingsStore) else { return }
        interactionHaptics.emitLightIfEnabled()
        applyTypingLanguage()
        let identifier = KeyboardTypingLanguage.current.identifier
        rootContainerView?.keyGridView.showLanguageCode(
            KeyboardTypingLanguageName.shortCode(
                for: identifier,
                among: KeyboardTypingLanguage.selection.identifiers
            ),
            name: KeyboardTypingLanguageName.displayName(for: identifier)
        )
    }

    /// Shows the keyboard in `KeyboardTypingLanguage.current`: the letter keys in its layout, and
    /// suggestions, swipes, and taps aimed at its files and keys, with what the keyboard learned in
    /// that language. Every change of language goes through here, so a transition between the
    /// layouts wraps this call.
    func applyTypingLanguage() {
        dropPendingSwipes()
        let memory = KeyboardTypingMemory.current
        memory.adoptResetIfNeeded()
        predictionCoordinator.setLanguage(KeyboardTypingLanguage.current, memory: memory.memory)
        applyLearnedVocabulary()
        rootContainerView?.keyGridView.showCurrentLetterLayout()
        // Until the host hands over the field, it is read only once it does.
        guard awaitsFieldState == false else { return }
        restartTypingInCurrentLanguage()
    }
}
