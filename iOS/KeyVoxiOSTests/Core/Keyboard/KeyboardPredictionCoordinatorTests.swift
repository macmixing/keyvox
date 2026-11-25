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
        coordinator.updateGeometry(Self.letterKeys, keyboardSize: CGSize(width: 390, height: 216))
        coordinator.reset()
        let path = try Self.swipe(through: "the")
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

    /// The letter keys of a 390-point-wide iPhone keyboard's three letter rows.
    private static let letterKeys: [KeyboardCharacterKeyGeometry] = {
        let rows: [(letters: String, inset: CGFloat)] = [("qwertyuiop", 3), ("asdfghjkl", 22.5), ("zxcvbnm", 61.5)]
        return rows.enumerated().flatMap { row, entry in
            entry.letters.enumerated().map { index, letter in
                KeyboardCharacterKeyGeometry(
                    character: letter,
                    frame: CGRect(x: entry.inset + CGFloat(index) * 39, y: 10 + CGFloat(row) * 54, width: 33, height: 42)
                )
            }
        }
    }()

    /// A finger's path from key center to key center through `word`'s letters, sampled every 16 ms.
    private static func swipe(through word: String) throws -> [SwipeTouchSample] {
        let centers = try word.map { letter in
            let frame = try #require(letterKeys.first { $0.character == letter }).frame
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        var samples = [SwipeTouchSample(location: centers[0], timestamp: 0)]
        for (from, to) in zip(centers, centers.dropFirst()) {
            for step in 1...8 {
                let fraction = CGFloat(step) / 8
                samples.append(SwipeTouchSample(
                    location: CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction),
                    timestamp: samples[samples.count - 1].timestamp + 0.016
                ))
            }
        }
        return samples
    }
}
