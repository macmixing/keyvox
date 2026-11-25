import KeyVoxPredictiveKeyboard
import UIKit

/// Swipe typing: a word swiped across the letter keys goes in as a word picked from the
/// suggestion bar would, written as typing writes it. The bar keeps what it showed while the
/// finger swipes, then shows what follows the word, as after any word.
extension KeyboardViewController {
    /// Lets the keys swipe words where the focused field and the user's settings allow it.
    func updateSwipeTyping() {
        rootContainerView?.keyGridView.allowsSwipeTyping = typingTraits.allowsSwipeTyping
    }

    /// Types the word `path` was swiped as. The word of the swipe before goes in first, then a word
    /// in progress ends, as a space would end it, so the shift state applies to the swiped word as
    /// to typed letters, in the order they were swiped. The swipe ending plays a letter key's
    /// press haptic, as a typed letter does.
    func handleSwipe(_ path: [SwipeTouchSample]) {
        guard typingTraits.allowsSwipeTyping else { return }
        predictionCoordinator.finishPendingSwipe()
        characterKeyHaptics.emitKeypressIfEnabled()
        dismissRescuedDictation()
        if predictionCoordinator.hasWordInProgress() {
            textInputController.apply(predictionCoordinator.wordBoundaryEdit(
                separator: " ",
                allowsAutocorrection: typingTraits.allowsAutocorrection
            ))
            handleTypingContextChange()
        }
        predictionCoordinator.decodeSwipe(path, wordCase: swipeWordCase) { [weak self] word in
            self?.insertSwipedWord(word)
        }
    }

    /// Hands over a swipe still being decided or decoded, so what the user does next follows its
    /// word. A finger the key grid holds undecided is a swipe once the user acts anywhere but on
    /// the keys.
    func finishPendingSwipe() {
        rootContainerView?.keyGridView.settleUndecidedSwipes(at: .infinity)
        predictionCoordinator.finishPendingSwipe()
    }

    /// The capitals the shift state gives a swiped word.
    private var swipeWordCase: SwipeWordCase {
        switch letterCaseController.letterCase {
        case .lowercase: .asSpelled
        case .shifted: .capitalized
        case .capsLocked: .allCapitals
        }
    }

    private func insertSwipedWord(_ word: String?) {
        guard let word else { return }
        textInputController.apply(predictionCoordinator.swipeEdit(word: word))
        letterCaseController.consumeTypedLetter()
        handleTypingContextChange()
    }
}

