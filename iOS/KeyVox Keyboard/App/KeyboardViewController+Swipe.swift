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
    /// to typed letters, in the order they were swiped. A swipe the key grid held undecided since
    /// `heldPlace` goes nowhere once the cursor or the field has moved from there. The swipe
    /// ending plays a letter key's press haptic, as a typed letter does.
    func handleSwipe(_ path: [SwipeTouchSample], heldSince heldPlace: KeyboardSwipePlace?) {
        guard typingTraits.allowsSwipeTyping else { return }
        predictionCoordinator.finishPendingSwipe()
        if let heldPlace, heldPlace != predictionCoordinator.swipePlace() { return }
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

    /// Where a swipe the key grid holds undecided would put its word: after the word of the swipe
    /// before it, which goes in now.
    func heldSwipePlace() -> KeyboardSwipePlace {
        predictionCoordinator.finishPendingSwipe()
        return predictionCoordinator.swipePlace()
    }

    /// Forgets the swipes held undecided or being decoded, whose words then go nowhere, as when
    /// another field takes the keyboard.
    func dropPendingSwipes() {
        rootContainerView?.keyGridView.dropUndecidedSwipes()
        predictionCoordinator.dropPendingSwipe()
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

