import KeyVoxPredictiveKeyboard
import UIKit

/// Letter-page typing: shift state, predictions, and autocorrection at word boundaries.
extension KeyboardViewController {
    private static let wordEndingPunctuation: Set<String> = [".", ",", "!", "?", ";", ":"]

    /// Reads the focused field's traits and starts it on the right page with a fresh
    /// typing session.
    func prepareTypingForCurrentField() {
        typingTraits = KeyboardTypingTraits(proxy: textDocumentProxy)
        if keysMode == .compact {
            symbolPage = .primary
        } else {
            symbolPage = typingTraits.prefersNumberPage ? .primary : .letters
        }
        predictionCoordinator.reset()
        if typingTraits.allowsPredictions {
            predictionCoordinator.prepare()
            loadPersonalVocabulary()
        }
        letterCaseController.reset()
        synchronizeLetterCase()
        refreshPredictions()
    }

    /// Call after any change to the text or cursor, including the keyboard's own edits.
    func handleTypingContextChange() {
        predictionCoordinator.textDidChange()
        synchronizeLetterCase()
        refreshPredictions()
        updateActiveInsertionVisualState()
    }

    /// Handles letter-page keys before the regular text input path. Returns nil when the
    /// regular path should handle the key.
    func handleTypingActivation(_ activation: KeyboardKeyActivation) -> Bool? {
        switch activation.kind {
        case .shift:
            letterCaseController.handleShift(at: activation.timestamp)
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
        textInputController.apply(predictionCoordinator.choiceEdit(item))
        handleTypingContextChange()
    }

    /// Hands the engine the user's KeyVox Dictionary, contact names, and text replacements.
    private func loadPersonalVocabulary() {
        let dictionaryPhrases = dictionaryCasingStore.dictionaryPhrases()
        requestSupplementaryLexicon { [weak self] lexicon in
            self?.predictionCoordinator.updateVocabulary(
                KeyboardPersonalVocabularyBuilder.vocabulary(
                    dictionaryPhrases: dictionaryPhrases,
                    lexicon: lexicon
                )
            )
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

    private func refreshPredictions() {
        guard typingTraits.allowsPredictions, symbolPage == .letters else {
            predictionCoordinator.clearBar()
            return
        }
        predictionCoordinator.refresh(allowsAutocorrection: typingTraits.allowsAutocorrection)
    }

    /// Applies an autocorrection, if one is due, together with the separator that ended
    /// the word. Returns nil when there is no correction so the regular path inserts the
    /// separator (keeping behaviors such as the double-space period).
    private func applyWordBoundary(separator: String, emitsKeypress: Bool) -> Bool? {
        guard typingTraits.allowsPredictions,
              let edit = predictionCoordinator.wordBoundaryEdit(
                  separator: separator,
                  allowsAutocorrection: typingTraits.allowsAutocorrection
              ),
              edit.deleteCount > 0 else {
            return nil
        }
        if emitsKeypress {
            keypressHaptics.emitKeypressIfEnabled()
        }
        textInputController.apply(edit)
        handleTypingContextChange()
        return true
    }
}
