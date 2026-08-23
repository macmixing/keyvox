import Foundation
import Testing
@testable import KeyVox_iOS

struct KeyboardTextInputControllerTests {
    @Test func characterKeyInsertsTextAndEmitsHaptics() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )
        var symbolPage = KeyboardSymbolPage.primary

        let handled = controller.handleKeyActivation(
            .character("A"),
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {},
            advanceToNextInputMode: {}
        )

        #expect(handled == true)
        #expect(documentProxy.insertedTexts == ["A"])
        #expect(haptics.emissionCount == 1)
        #expect(symbolPage == .primary)
    }

    @Test func secondSpaceAfterWordInsertsPeriodAndSpace() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "Hello "
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )
        var symbolPage = KeyboardSymbolPage.primary

        let handled = controller.handleKeyActivation(
            .space,
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {},
            advanceToNextInputMode: {}
        )

        #expect(handled == true)
        #expect(documentProxy.deleteBackwardCallCount == 1)
        #expect(documentProxy.insertedTexts == [". "])
        #expect(haptics.emissionCount == 1)
    }

    @Test func deleteKeyRemovesSelectedTextWithoutLeadingContext() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.selectedText = "Hello"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )
        var symbolPage = KeyboardSymbolPage.primary

        let handled = controller.handleKeyActivation(
            .delete,
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {},
            advanceToNextInputMode: {}
        )

        #expect(handled == true)
        #expect(documentProxy.deleteBackwardCallCount == 1)
        #expect(haptics.emissionCount == 1)
    }

    @Test func deleteKeyUsesHasTextWhenLeadingContextIsUnavailableAtDocumentEnd() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = ""
        documentProxy.documentContextAfterInput = ""
        documentProxy.hasText = true
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )
        var symbolPage = KeyboardSymbolPage.primary

        let handled = controller.handleKeyActivation(
            .delete,
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {},
            advanceToNextInputMode: {}
        )

        #expect(handled == true)
        #expect(documentProxy.deleteBackwardCallCount == 1)
        #expect(haptics.emissionCount == 1)
    }

    @Test func deleteKeyPerformsPhantomDeleteWhenFieldSeemsEmpty() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = ""
        documentProxy.documentContextAfterInput = ""
        documentProxy.hasText = false
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )
        var symbolPage = KeyboardSymbolPage.primary

        // Attempt 1: Ghost delete, emits haptic
        let handled1 = controller.handleKeyActivation(.delete, symbolPage: &symbolPage, resetCapsLockStateIfNeeded: {}, advanceToNextInputMode: {})
        #expect(handled1 == true)
        #expect(documentProxy.deleteBackwardCallCount == 1)
        #expect(haptics.emissionCount == 1)

        // Attempt 2: Ghost delete, silent
        let handled2 = controller.handleKeyActivation(.delete, symbolPage: &symbolPage, resetCapsLockStateIfNeeded: {}, advanceToNextInputMode: {})
        #expect(handled2 == true)
        #expect(documentProxy.deleteBackwardCallCount == 2)
        #expect(haptics.emissionCount == 1)

        // Attempt 3: Ghost delete, silent
        let handled3 = controller.handleKeyActivation(.delete, symbolPage: &symbolPage, resetCapsLockStateIfNeeded: {}, advanceToNextInputMode: {})
        #expect(handled3 == true)
        #expect(documentProxy.deleteBackwardCallCount == 3)
        #expect(haptics.emissionCount == 1)

        // Attempt 4: Exhausted phantom deletes, cancels repeater
        let handled4 = controller.handleKeyActivation(.delete, symbolPage: &symbolPage, resetCapsLockStateIfNeeded: {}, advanceToNextInputMode: {})
        #expect(handled4 == false)
        #expect(documentProxy.deleteBackwardCallCount == 3)
        #expect(haptics.emissionCount == 1)
    }

    @Test func deleteKeyIgnoresTrailingContextToBypassIOSBugs() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = ""
        documentProxy.documentContextAfterInput = "phantom text"
        documentProxy.hasText = true
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )
        var symbolPage = KeyboardSymbolPage.primary

        // Should return true to allow deletion logic to proceed, bypassing buggy trailing contexts
        let handled = controller.handleKeyActivation(.delete, symbolPage: &symbolPage, resetCapsLockStateIfNeeded: {}, advanceToNextInputMode: {})

        #expect(handled == true)
        #expect(documentProxy.deleteBackwardCallCount == 1)
        #expect(haptics.emissionCount == 1)
    }

    @Test func abcKeyTriggersCapsResetAndInputModeAdvance() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )
        var symbolPage = KeyboardSymbolPage.primary
        var resetCount = 0
        var advanceCount = 0

        let handled = controller.handleKeyActivation(
            .abc,
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {
                resetCount += 1
            },
            advanceToNextInputMode: {
                advanceCount += 1
            }
        )

        #expect(handled == true)
        #expect(resetCount == 1)
        #expect(advanceCount == 1)
        #expect(haptics.emissionCount == 1)
    }

    @Test func symbolKeyTogglesSymbolPage() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )
        var symbolPage = KeyboardSymbolPage.primary

        let handled = controller.handleKeyActivation(
            .alternateSymbols,
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {},
            advanceToNextInputMode: {}
        )

        #expect(handled == true)
        #expect(symbolPage == .alternate)
        #expect(haptics.emissionCount == 1)
    }

    @Test func transcriptionInsertionTrimsTrailingNewlinesAndAddsLeadingSpaceWhenNeeded() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "Hello"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("world\n\n")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" world"])
        #expect(haptics.emissionCount == 0)
    }

    @Test func selectedWordReplacementPreservesExistingPunctuationAfterStrippingModelPeriod() {
        let preservationCases = [
            (original: "You said it was fine.", expected: "You said it was working."),
            (original: "You said it was fine?", expected: "You said it was working?"),
            (original: "You said it was fine!", expected: "You said it was working!"),
            (original: "You said it was fine, right?", expected: "You said it was working, right?"),
            (original: "You said it was fine; I disagreed.", expected: "You said it was working; I disagreed."),
            (original: "The status was fine: ready to ship.", expected: "The status was working: ready to ship."),
            (original: "You described it as (fine)", expected: "You described it as (working)"),
            (original: "You said it was fine—ready to ship.", expected: "You said it was working—ready to ship."),
            (original: "You said it was fine…for now.", expected: "You said it was working…for now."),
        ]
        for testCase in preservationCases {
            let documentProxy = StatefulSelectionDocumentProxy(
                text: testCase.original,
                selecting: "fine"
            )
            let controller = KeyboardTextInputController(
                documentProxy: documentProxy,
                emitKeypress: {}
            )

            let inserted = controller.insertTranscription("Working.")

            #expect(inserted == true)
            #expect(documentProxy.text == testCase.expected)
        }
    }

    @Test func selectedWordReplacementUsesExplicitQuestionOrExclamationMark() {
        let existingCases = [
            "You said it was fine.",
            "You said it was fine?",
            "You said it was fine!",
            "You said it was fine,",
        ]
        for incomingPunctuation in ["?", "!"] {
            for original in existingCases {
                let documentProxy = StatefulSelectionDocumentProxy(
                    text: original,
                    selecting: "fine"
                )
                let controller = KeyboardTextInputController(
                    documentProxy: documentProxy,
                    emitKeypress: {}
                )
                let replacement = "Working\(incomingPunctuation)"

                let inserted = controller.insertTranscription(replacement)

                #expect(inserted == true)
                #expect(documentProxy.text == "You said it was working\(incomingPunctuation)")
            }
        }
    }

    @Test func transcriptionInsertionAddsTrailingSeparatorBeforeExistingWordText() {
        let insertionCases = [
            (
                original: "That's cool.",
                followingText: "That's cool.",
                transcription: "What's up?",
                expected: "What's up? That's cool."
            ),
            (
                original: "You're good.",
                followingText: "You're good.",
                transcription: "That's awesome.",
                expected: "That's awesome. You're good."
            ),
            (
                original: "That's awesome.",
                followingText: "awesome.",
                transcription: "definitely",
                expected: "That's definitely awesome."
            ),
            (
                original: "😎",
                followingText: "😎",
                transcription: "Nice",
                expected: "Nice 😎"
            ),
        ]
        for testCase in insertionCases {
            let documentProxy = StatefulSelectionDocumentProxy(
                text: testCase.original,
                caretBefore: testCase.followingText
            )
            let controller = KeyboardTextInputController(
                documentProxy: documentProxy,
                emitKeypress: {}
            )

            let inserted = controller.insertTranscription(testCase.transcription)

            #expect(inserted == true)
            #expect(documentProxy.text == testCase.expected)
        }
    }

    @Test func transcriptionInsertionPreservesPeriodBeforeNewLineAndURLContent() {
        let insertionCases = [
            (followingText: "\ntest", expected: "This is cool.\ntest"),
            (followingText: "\nhttps://example.com", expected: "This is cool.\nhttps://example.com"),
            (followingText: "https://example.com", expected: "This is cool. https://example.com"),
        ]
        for testCase in insertionCases {
            let documentProxy = StatefulSelectionDocumentProxy(
                text: testCase.followingText,
                caretBefore: testCase.followingText
            )
            let controller = KeyboardTextInputController(
                documentProxy: documentProxy,
                emitKeypress: {}
            )

            let inserted = controller.insertTranscription("This is cool.")

            #expect(inserted == true)
            #expect(documentProxy.text == testCase.expected)
        }
    }

    @Test func transcriptionInsertionDoesNotAddTrailingSeparatorBeforePunctuation() {
        for punctuation in [".", ",", "?", "!", ":", ";"] {
            let original = "That's\(punctuation)"
            let documentProxy = StatefulSelectionDocumentProxy(
                text: original,
                caretBefore: punctuation
            )
            let controller = KeyboardTextInputController(
                documentProxy: documentProxy,
                emitKeypress: {}
            )

            let inserted = controller.insertTranscription("definitely")

            #expect(inserted == true)
            #expect(documentProxy.text == "That's definitely\(punctuation)")
        }
    }

    @Test func transcriptionRepairsStaleSpaceAfterDeletingSelection() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "Previous sentence. "
        documentProxy.selectedText = "Deleted sentence."
        documentProxy.hasText = true
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: {}
        )
        var symbolPage = KeyboardSymbolPage.primary

        let deleted = controller.handleKeyActivation(
            .delete,
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {},
            advanceToNextInputMode: {}
        )
        documentProxy.selectedText = nil
        let insertion = controller.insertTranscriptionWithResult("Replacement sentence.")

        #expect(deleted == true)
        #expect(documentProxy.insertedTexts == [" Replacement sentence."])
        #expect(insertion?.documentContextBeforeInput == "Previous sentence.")
    }

    @Test func interveningTypingClearsSelectionDeletionCorrection() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "Previous sentence. "
        documentProxy.selectedText = "Deleted sentence."
        documentProxy.hasText = true
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: {}
        )
        var symbolPage = KeyboardSymbolPage.primary

        _ = controller.handleKeyActivation(
            .delete,
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {},
            advanceToNextInputMode: {}
        )
        documentProxy.selectedText = nil
        _ = controller.handleKeyActivation(
            .character("x"),
            symbolPage: &symbolPage,
            resetCapsLockStateIfNeeded: {},
            advanceToNextInputMode: {}
        )
        _ = controller.insertTranscription("Replacement sentence.")

        #expect(documentProxy.insertedTexts == ["x", "Replacement sentence."])
    }

    @Test func transcriptionInsertionKeepsLeadingCapitalizationAtEmptyContext() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == ["Hello"])
    }

    @Test func transcriptionInsertionKeepsLeadingCapitalizationAfterPeriod() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "Hello. "
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == ["Hello"])
    }

    @Test func transcriptionInsertionKeepsLeadingCapitalizationAfterQuestionMark() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "Hello? "
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == ["Hello"])
    }

    @Test func transcriptionInsertionKeepsLeadingCapitalizationAfterExclamationMark() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "Hello! "
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == ["Hello"])
    }

    @Test func transcriptionInsertionUsesSharedPolicyAfterOpeningQuote() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "I was about to say, \""
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: {}
        )

        let inserted = controller.insertTranscription("This is cool.")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == ["This is cool."])
    }

    @Test func transcriptionInsertionUsesSharedPolicyAfterClosingQuoteContinuation() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "I told Johnny, \"you're going to be late,\""
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: {}
        )

        let inserted = controller.insertTranscription("But he didn't listen.")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" but he didn't listen."])
    }

    @Test func transcriptionInsertionUsesSharedPolicyAfterQuotedSentenceBoundary() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "Did you say, \"what's up?\""
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: {}
        )

        let inserted = controller.insertTranscription("We missed that.")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" We missed that."])
    }

    @Test func transcriptionInsertionKeepsLeadingCapitalizationAtStartOfNewLine() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there\n"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == ["Hello"])
    }

    @Test func transcriptionInsertionKeepsLeadingCapitalizationAfterNewLineAndIndentation() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there\n   "
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == ["Hello"])
    }

    @Test func transcriptionInsertionLowercasesDefaultSentenceCaseMidSentence() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" hello"])
    }

    @Test func transcriptionInsertionLowercasesDefaultSentenceCaseWithLeadingWhitespaceMidSentence() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello there")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" hello there"])
    }

    @Test func transcriptionInsertionPreservesAllCapsMidSentence() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("NASA launched")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" NASA launched"])
    }

    @Test func transcriptionInsertionPreservesMixedCaseMidSentence() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("OpenAI launched")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" OpenAI launched"])
    }

    @Test func transcriptionInsertionLowercasesSentenceCaseBeforePunctuationMidSentence() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello, world")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" hello, world"])
    }

    @Test func transcriptionInsertionPreservesLeadingNonLetterMidSentence() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("1Password launched")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" 1Password launched"])
    }

    @Test func transcriptionInsertionReplacementPathStillNormalizesCapitalization() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there"
        documentProxy.selectedText = "world"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled
        )

        let inserted = controller.insertTranscription("Hello")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" hello"])
    }

    @Test func transcriptionInsertionPreservesDictionaryCasedNameMidSentence() {
        let documentProxy = KeyboardTextDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "hello there"
        let haptics = KeyboardKeypressHapticsSpy()
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: haptics.emitKeypressIfEnabled,
            shouldPreserveLeadingCapitalization: { text in
                text.hasPrefix("Dom Esposito")
            }
        )

        let inserted = controller.insertTranscription("Dom Esposito.")

        #expect(inserted == true)
        #expect(documentProxy.insertedTexts == [" Dom Esposito."])
    }
}

private final class KeyboardTextDocumentProxySpy: KeyboardTextDocumentProxying {
    var documentContextBeforeInput: String?
    var documentContextAfterInput: String?
    var hasText = false
    var selectedText: String?
    var insertedTexts: [String] = []
    var deleteBackwardCallCount = 0
    var adjustedOffsets: [Int] = []

    func insertText(_ text: String) {
        insertedTexts.append(text)
    }

    func deleteBackward() {
        deleteBackwardCallCount += 1
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        adjustedOffsets.append(offset)
    }
}

private final class KeyboardKeypressHapticsSpy {
    var emissionCount = 0

    func emitKeypressIfEnabled() {
        emissionCount += 1
    }
}

private final class StatefulSelectionDocumentProxy: KeyboardTextDocumentProxying {
    private var characters: [Character]
    private var selection: Range<Int>?
    private var caretLocation: Int

    init(text: String, selecting selectedText: String) {
        characters = Array(text)
        guard let selectedRange = text.range(of: selectedText) else {
            preconditionFailure("Selected test text must exist in the document")
        }
        let lowerBound = text.distance(from: text.startIndex, to: selectedRange.lowerBound)
        let upperBound = text.distance(from: text.startIndex, to: selectedRange.upperBound)
        selection = lowerBound..<upperBound
        caretLocation = lowerBound
    }

    init(text: String, caretBefore followingText: String) {
        characters = Array(text)
        guard let followingRange = text.range(of: followingText) else {
            preconditionFailure("Following test text must exist in the document")
        }
        selection = nil
        caretLocation = text.distance(from: text.startIndex, to: followingRange.lowerBound)
    }

    var text: String { String(characters) }
    var documentContextBeforeInput: String? {
        String(characters[..<(selection?.lowerBound ?? caretLocation)])
    }
    var documentContextAfterInput: String? {
        String(characters[(selection?.upperBound ?? caretLocation)...])
    }
    var hasText: Bool { characters.isEmpty == false }
    var selectedText: String? {
        guard let selection else { return nil }
        return String(characters[selection])
    }

    func insertText(_ text: String) {
        let insertedCharacters = Array(text)
        if let selection {
            characters.replaceSubrange(selection, with: insertedCharacters)
            caretLocation = selection.lowerBound + insertedCharacters.count
            self.selection = nil
        } else {
            characters.insert(contentsOf: insertedCharacters, at: caretLocation)
            caretLocation += insertedCharacters.count
        }
    }

    func deleteBackward() {
        guard caretLocation > 0 else { return }
        characters.remove(at: caretLocation - 1)
        caretLocation -= 1
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        caretLocation = min(max(0, caretLocation + offset), characters.count)
        selection = nil
    }
}
