import CoreGraphics
import KeyVoxPredictiveKeyboard
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyboardPredictionCoordinatorTests {
    @Test func emojiLoadUpdatesTheBarWithoutReadingTheDocument() throws {
        let word = "abc"
        var documentReads = 0
        let coordinator = KeyboardPredictionCoordinator(
            memory: TypingMemory(),
            textBeforeCursor: {
                documentReads += 1
                return word
            },
            selectedText: {
                documentReads += 1
                return nil
            },
            textAfterCursor: {
                documentReads += 1
                return nil
            }
        )
        var bar: SuggestionBar?
        coordinator.onBarChange = { bar = $0 }

        // Prime the result synchronously, as a word-boundary key would.
        _ = coordinator.wordBoundaryEdit(separator: " ", allowsAutocorrection: true)
        coordinator.refresh(allowsAutocorrection: true)
        let originalBar = try #require(bar)
        let readsBeforeEmojiLoad = documentReads
        let emoji = "🔑"
        coordinator.emojiForWord = { $0 == word ? [emoji] : [] }

        coordinator.refreshEmojiSuggestions()

        #expect(documentReads == readsBeforeEmojiLoad)
        #expect(bar == originalBar.showing(emoji: [emoji]))

        coordinator.clearBar()
        coordinator.refreshEmojiSuggestions()

        #expect(documentReads == readsBeforeEmojiLoad)
        #expect(bar == SuggestionBar.empty)
    }

    @Test func aSwipedWordGoesOnlyWhereItWasSwiped() {
        var textBeforeCursor = "I am "
        let coordinator = KeyboardPredictionCoordinator(
            memory: TypingMemory(),
            textBeforeCursor: { textBeforeCursor },
            selectedText: { nil },
            textAfterCursor: { nil }
        )
        let path = [
            SwipeTouchSample(location: .zero, timestamp: 0),
            SwipeTouchSample(location: CGPoint(x: 40, y: 0), timestamp: 0.2),
        ]
        var handedOver = 0

        coordinator.decodeSwipe(path, wordCase: .asSpelled) { _ in handedOver += 1 }
        coordinator.finishPendingSwipe()
        #expect(handedOver == 1, "the cursor stayed where the swipe ended")

        coordinator.decodeSwipe(path, wordCase: .asSpelled) { _ in handedOver += 1 }
        textBeforeCursor += "there. "
        coordinator.finishPendingSwipe()
        #expect(handedOver == 1, "the cursor moved before the word arrived")

        coordinator.decodeSwipe(path, wordCase: .asSpelled) { _ in handedOver += 1 }
        coordinator.dropPendingSwipe()
        coordinator.finishPendingSwipe()
        #expect(handedOver == 1, "another field took the keyboard")
    }
}
