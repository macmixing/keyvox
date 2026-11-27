import CoreGraphics
import Foundation
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
            },
            documentIdentifier: { nil }
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

    @Test func aSwipedWordGoesOnlyWhereItWasSwiped() throws {
        var textBeforeCursor = "I am "
        var document = UUID()
        let coordinator = KeyboardPredictionCoordinator(
            memory: TypingMemory(),
            textBeforeCursor: { textBeforeCursor },
            selectedText: { nil },
            textAfterCursor: { nil },
            documentIdentifier: { document }
        )
        coordinator.updateGeometry(KeyboardSwipeTestPath.letterKeys, keyboardSize: KeyboardSwipeTestPath.keyboardSize)
        coordinator.reset()
        let path = try KeyboardSwipeTestPath.through("the")
        var edits: [TextEdit] = []

        coordinator.decodeSwipe(path, wordCase: .asSpelled) { edits.append($0) }
        coordinator.finishPendingSwipe()
        #expect(edits.count == 1, "the cursor stayed where the swipe ended")

        coordinator.decodeSwipe(path, wordCase: .asSpelled) { edits.append($0) }
        textBeforeCursor += "there. "
        coordinator.textDidChange()
        coordinator.finishPendingSwipe()
        #expect(edits.count == 1, "the cursor moved before the word arrived")

        // Another field of the same kind, with the same text around the cursor.
        coordinator.decodeSwipe(path, wordCase: .asSpelled) { edits.append($0) }
        document = UUID()
        coordinator.textDidChange()
        coordinator.finishPendingSwipe()
        #expect(edits.count == 1, "another field with the same text took the keyboard")

        coordinator.decodeSwipe(path, wordCase: .asSpelled) { edits.append($0) }
        coordinator.leaveField()
        coordinator.finishPendingSwipe()
        #expect(edits.count == 1, "the keyboard went away")
    }
}
