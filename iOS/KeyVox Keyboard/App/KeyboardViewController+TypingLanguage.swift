import KeyVoxPredictiveKeyboard
import UIKit

/// The typing language: following the user's languages and layouts, and the one place a change of
/// language reaches the keys, predictions, swipes, taps, and what the keyboard learned.
extension KeyboardViewController {
    /// Rereads the user's typing languages, as each time the keyboard shows or its host comes back,
    /// judges the user's known names against them again when they changed, and shows the language
    /// they give when it changed.
    func adoptTypingLanguageSettings() {
        let previousLanguages = KeyboardTypingLanguage.selection.identifiers
        let changed = KeyboardTypingLanguage.adoptSettings(appSettingsStore)
        if KeyboardTypingLanguage.selection.identifiers != previousLanguages {
            applyUserVocabulary()
        }
        rootContainerView?.keyGridView.allowsSpaceLanguageSlide = KeyboardTypingLanguage.selection.languages.count > 1
        showLanguageCode()
        guard changed else { return }
        applyTypingLanguage()
    }

    /// Switches to the selected language `offset` places from the current one, as a slide across
    /// the space bar asks: a light haptic, the keyboard in the new language, its keys turning over
    /// in a wave that goes the way the finger slid, and its short code on the space bar.
    func switchTypingLanguage(by offset: Int) {
        guard KeyboardTypingLanguage.switchLanguage(by: offset, settings: appSettingsStore) else { return }
        interactionHaptics.emitLightIfEnabled()
        applyTypingLanguage(keyFlipDirection: offset < 0 ? .rightToLeft : .leftToRight)
        showLanguageCode()
    }

    /// Writes the short code of the language the keyboard types in on the space bar while the
    /// keyboard has more than one language, as Apple's keyboard does, and none with one.
    private func showLanguageCode() {
        let selection = KeyboardTypingLanguage.selection
        guard selection.languages.count > 1 else {
            rootContainerView?.keyGridView.languageCode = nil
            return
        }
        let identifier = KeyboardTypingLanguage.current.identifier
        rootContainerView?.keyGridView.languageCode = (
            code: KeyboardTypingLanguageName.shortCode(for: identifier, among: selection.identifiers),
            name: KeyboardTypingLanguageName.displayName(for: identifier)
        )
    }

    /// Shows the keyboard in `KeyboardTypingLanguage.current`: the letter keys in its layout, and
    /// suggestions, swipes, and taps aimed at its files and keys, with what the keyboard learned in
    /// that language. Every change of language goes through here, so here the keys on screen turn
    /// over into the new layout's (`KeyboardKeyFlipTransition`), in a wave going `keyFlipDirection`.
    func applyTypingLanguage(keyFlipDirection: KeyboardKeyFlipWave.Direction = .leftToRight) {
        dropPendingSwipes()
        let memory = KeyboardTypingMemory.current
        memory.adoptResetIfNeeded()
        predictionCoordinator.setLanguage(KeyboardTypingLanguage.current, memory: memory.memory)
        applyLearnedVocabulary()
        rootContainerView?.keyGridView.showCurrentLetterLayout(flipDirection: keyFlipDirection)
        // Until the host hands over the field, it is read only once it does.
        guard awaitsFieldState == false else { return }
        restartTypingInCurrentLanguage()
    }
}
