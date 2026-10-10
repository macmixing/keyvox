import KeyVoxPredictiveKeyboard
import UIKit

/// Letter-page typing: shift state, predictions, and autocorrection at word boundaries.
extension KeyboardViewController {
    private static let wordEndingPunctuation: Set<String> = [".", ",", "!", "?", ";", ":"]

    /// Reads the focused field's traits and starts it on the right page with a fresh
    /// typing session.
    func prepareTypingForCurrentField() {
        typingTraits = KeyboardTypingTraits(proxy: textDocumentProxy, settings: appSettingsStore)
        fieldHasLetters = fieldHoldsLetters()
        applyOpeningLayout(prefersNumberPage: typingTraits.prefersNumberPage)
        predictionCoordinator.reset()
        if typingTraits.allowsPredictions {
            predictionCoordinator.prepare()
            applyLearnedVocabulary()
            loadPersonalVocabulary()
        }
        letterCaseController.reset()
        synchronizeLetterCase()
        refreshPredictions()
    }

    /// Opens on the page and key size `KeyboardOpeningLayout` picks.
    func applyOpeningLayout(prefersNumberPage: Bool) {
        let layout = KeyboardOpeningLayout.resolve(
            prefersNumberPage: prefersNumberPage,
            isCompactKeysEnabled: appSettingsStore.isCompactKeysEnabled,
            isCompactKeysActive: appSettingsStore.isCompactKeysActive
        )
        keysMode = layout.keysMode
        symbolPage = layout.symbolPage
    }

    /// Call after any change to the text or cursor, including the keyboard's own edits. A
    /// change of the field's traits means the cursor moved to another field while the
    /// keyboard stayed up, which starts that field fresh.
    func handleTypingContextChange() {
        guard KeyboardTypingTraits(proxy: textDocumentProxy, settings: appSettingsStore) == typingTraits else {
            prepareTypingForCurrentField()
            updateActiveInsertionVisualState()
            return
        }
        fieldHasLetters = fieldHoldsLetters()
        predictionCoordinator.textDidChange()
        synchronizeLetterCase()
        refreshPredictions()
        updateActiveInsertionVisualState()
    }

    /// Whether the text around the cursor holds any letters; spaces, digits, punctuation, and
    /// emoji alone do not count.
    private func fieldHoldsLetters() -> Bool {
        [
            textDocumentProxy.documentContextBeforeInput,
            textDocumentProxy.selectedText,
            textDocumentProxy.documentContextAfterInput,
        ].contains { text in
            text?.contains(where: \.isLetter) ?? false
        }
    }

    /// Handles letter-page keys before the regular text input path. Returns nil when the
    /// regular path should handle the key.
    func handleTypingActivation(_ activation: KeyboardKeyActivation) -> Bool? {
        switch activation.kind {
        case .shift:
            letterCaseController.handleShift(
                at: activation.timestamp,
                allowsCapsLock: typingTraits.allowsCapsLock
            )
            keypressHaptics.emitKeypressIfEnabled()
            applyLetterCase()
            return true
        case .space:
            return applyWordBoundary(separator: " ", emitsKeypress: true)
        case .returnKey:
            return applyWordBoundary(separator: "\n", emitsKeypress: true)
        case let .character(value) where Self.wordEndingPunctuation.contains(value):
            return applyWordBoundary(separator: value, emitsKeypress: false)
        case .delete:
            guard typingTraits.allowsPredictions,
                  let edit = predictionCoordinator.backspaceEdit() else {
                return nil
            }
            keypressHaptics.emitKeypressIfEnabled()
            textInputController.apply(edit)
            handleTypingContextChange()
            return true
        default:
            return nil
        }
    }

    /// Deletes whole words for a held delete key. Returns false when no word could be deleted.
    func handleDeleteWords(_ count: Int) -> Bool {
        textInputController.deleteWordsBackward(count) { [weak self] in
            self?.handleTypingContextChange()
        }
    }

    /// A first press of space, return, shift, delete, 123, or the globe that landed close to
    /// a letter key types that letter instead when the letter is the likelier intent.
    func resolveContestedTap(_ activation: KeyboardKeyActivation) -> KeyboardKeyActivation {
        guard let otherKey = contestedOtherKey(for: activation),
              let letter = predictionCoordinator.intendedLetter(
                  forTapAt: activation.location,
                  onKeyWithFrame: activation.keyFrame,
                  otherKey: otherKey
              ) else {
            return activation
        }
        keypressHaptics.emitKeypressIfEnabled()
        let letterKey = KeyboardKeyModel(kind: .character(String(letter)), widthUnits: 1)
            .applying(letterCaseController.letterCase)
        return KeyboardKeyActivation(
            kind: letterKey.kind,
            location: activation.location,
            keyFrame: activation.keyFrame,
            timestamp: activation.timestamp,
            isRepeat: false
        )
    }

    /// Returns to the letter page for a space that follows a symbol typed on a symbol page.
    /// Compact Keys and fields that open on the number page stay where they are.
    func updateSymbolPage(for kind: KeyboardKeyKind) {
        guard keysMode == .full, typingTraits.prefersNumberPage == false else { return }
        let page = symbolPageReturnTracker.page(for: kind, on: symbolPage)
        if page != symbolPage {
            symbolPage = page
        }
    }

    /// Records a typed letter's touch for prediction and ends a one-letter shift.
    func recordTypedCharacter(_ activation: KeyboardKeyActivation) {
        guard case let .character(value) = activation.kind,
              value.count == 1,
              value.first?.isLetter == true else {
            return
        }
        if symbolPage == .letters {
            predictionCoordinator.recordTap(at: activation.location)
        }
        letterCaseController.consumeTypedLetter()
    }

    func handleSuggestionSelected(_ item: SuggestionBar.Item) {
        interactionHaptics.emitLightIfEnabled()
        textInputController.apply(
            predictionCoordinator.choiceEdit(item, allowsAutocorrection: typingTraits.allowsAutocorrection)
        )
        handleTypingContextChange()
    }

    /// Forgets a word the keyboard learned from the user's typing, or the capitals it learned
    /// for a dictionary word, when the user presses and holds it in the suggestion bar, with the
    /// toolbar's thump; the user's own words stay, and nothing is felt.
    func handleSuggestionLongPressed(_ item: SuggestionBar.Item) {
        guard userVocabulary.contains(item.text) == false,
              KeyboardTypingMemory.shared.memory.forget(item.text) else {
            return
        }
        interactionHaptics.emitMediumIfEnabled()
    }

    /// Hands the suggestions the user's vocabulary: their KeyVox Dictionary at once, with the
    /// system's names and text replacements as last sent, and again whenever the system sends
    /// them, since it may take long to or never answer.
    func loadPersonalVocabulary() {
        guard typingTraits.allowsPredictions else { return }
        let dictionaryPhrases = dictionaryCasingStore.dictionaryPhrases()
        applyPersonalVocabulary(dictionaryPhrases: dictionaryPhrases, lexicon: supplementaryLexicon)
        requestSupplementaryLexicon { [weak self] lexicon in
            guard let self else { return }
            self.supplementaryLexicon = lexicon
            self.applyPersonalVocabulary(dictionaryPhrases: dictionaryPhrases, lexicon: lexicon)
        }
    }

    /// Call when what the keyboard learned from the user's typing changes: suggests with it at
    /// once.
    func learnedVocabularyDidChange() {
        applyLearnedVocabulary()
        refreshPredictions()
    }

    /// Hands the suggestions what the keyboard learned from the user's typing.
    private func applyLearnedVocabulary() {
        predictionCoordinator.updateLearnedWords(KeyboardTypingMemory.shared.memory.learnedVocabulary)
    }

    private func applyPersonalVocabulary(dictionaryPhrases: [String], lexicon: UILexicon?) {
        let vocabulary = KeyboardPersonalVocabularyBuilder.vocabulary(dictionaryPhrases: dictionaryPhrases, lexicon: lexicon)
        userVocabulary = vocabulary
        predictionCoordinator.updateVocabulary(vocabulary)
        refreshPredictions()
    }

    /// Starts the check `resolveContestedTap` makes when the finger lands rather than when it
    /// lifts, so the answer is usually ready by then.
    func prepareContestedTap(_ activation: KeyboardKeyActivation) {
        guard let otherKey = contestedOtherKey(for: activation) else { return }
        predictionCoordinator.prepareIntendedLetter(
            forTapAt: activation.location,
            onKeyWithFrame: activation.keyFrame,
            otherKey: otherKey
        )
    }

    /// What kind of key `activation` presses, when it is a first press of a key whose taps
    /// close to a letter key may be meant for that letter.
    private func contestedOtherKey(for activation: KeyboardKeyActivation) -> ContestedTap.OtherKey? {
        guard symbolPage == .letters,
              typingTraits.allowsPredictions,
              activation.isRepeat == false else {
            return nil
        }
        return Self.contestedKey(for: activation.kind)
    }

    private static func contestedKey(for kind: KeyboardKeyKind) -> ContestedTap.OtherKey? {
        switch kind {
        case .space, .returnKey:
            return .wordBoundary
        case .shift, .delete, .numberSymbols, .nextKeyboard:
            return .control
        default:
            return nil
        }
    }

    func applyLetterCase() {
        rootContainerView?.keyGridView.setLetterCase(letterCaseController.letterCase)
    }

    private func synchronizeLetterCase() {
        letterCaseController.synchronize(
            textBeforeCursor: textDocumentProxy.documentContextBeforeInput,
            autocapitalization: typingTraits.autocapitalization
        )
        applyLetterCase()
    }

    /// Suggestions are only worked out while they are shown; a word boundary still works out
    /// its autocorrection on the spot when they are hidden.
    private func refreshPredictions() {
        guard typingTraits.showsSuggestions, symbolPage == .letters else {
            predictionCoordinator.clearBar()
            return
        }
        predictionCoordinator.refresh(allowsAutocorrection: typingTraits.allowsAutocorrection)
    }

    /// Applies an autocorrection, if one is due, together with the separator that ended
    /// the word. Returns nil when there is no correction so the regular path inserts the
    /// separator (keeping behaviors such as the double-space period).
    private func applyWordBoundary(separator: String, emitsKeypress: Bool) -> Bool? {
        guard typingTraits.allowsPredictions else { return nil }
        let edit = predictionCoordinator.wordBoundaryEdit(
            separator: separator,
            allowsAutocorrection: typingTraits.allowsAutocorrection
        )
        guard edit.deleteCount > 0 else { return nil }
        if emitsKeypress {
            keypressHaptics.emitKeypressIfEnabled()
        }
        textInputController.apply(edit)
        handleTypingContextChange()
        return true
    }
}
