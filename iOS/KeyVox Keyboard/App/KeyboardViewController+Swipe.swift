import KeyVoxPredictiveKeyboard
import UIKit

/// Swipe typing: a word swiped across the letter keys goes in as a word picked from the
/// suggestion bar would, written as typing writes it, with the other words it may have been on
/// the bar.
extension KeyboardViewController {
    /// Lets the keys swipe words where the focused field and the user's settings allow it.
    func updateSwipeTyping() {
        rootContainerView?.keyGridView.allowsSwipeTyping = typingTraits.allowsSwipeTyping
    }

    /// Types the word `path` was swiped as. A word in progress ends first, as a space would end
    /// it; the shift state applies to the swiped word as to typed letters.
    func handleSwipe(_ path: [SwipeTouchSample]) {
        guard typingTraits.allowsSwipeTyping else { return }
        dismissRescuedDictation()
        if predictionCoordinator.hasWordInProgress() {
            textInputController.apply(predictionCoordinator.wordBoundaryEdit(
                separator: " ",
                allowsAutocorrection: typingTraits.allowsAutocorrection
            ))
            handleTypingContextChange()
        }
        let wordCase: SwipeWordCase
        switch letterCaseController.letterCase {
        case .lowercase: wordCase = .asSpelled
        case .shifted: wordCase = .capitalized
        case .capsLocked: wordCase = .allCapitals
        }
        predictionCoordinator.decodeSwipe(path, wordCase: wordCase) { [weak self] words in
            self?.insertSwipedWords(words)
        }
    }

    /// Hands over a swipe still being decided or decoded, so what the user does next follows its
    /// word. A finger the key grid holds undecided is a swipe once the user acts anywhere but on
    /// the keys.
    func finishPendingSwipe() {
        rootContainerView?.keyGridView.settleUndecidedSwipes(at: .infinity)
        predictionCoordinator.finishPendingSwipe()
    }

    private func insertSwipedWords(_ words: [String]) {
        guard let edit = predictionCoordinator.swipeEdit(words: words) else { return }
        textInputController.apply(edit)
        letterCaseController.consumeTypedLetter()
        handleTypingContextChange()
    }
}

