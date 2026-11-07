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
}
