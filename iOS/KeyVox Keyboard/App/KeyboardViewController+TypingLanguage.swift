import UIKit

/// The typing language: following the user's languages and layouts, and the one place a change of
/// language reaches the keys, predictions, swipes, taps, and what the keyboard learned.
extension KeyboardViewController {
    /// Rereads the user's typing languages, as each time the keyboard shows or its host comes back,
    /// and shows the language they give when it changed.
    func adoptTypingLanguageSettings() {
        guard KeyboardTypingLanguage.adoptSettings(appSettingsStore) else { return }
        applyTypingLanguage()
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
