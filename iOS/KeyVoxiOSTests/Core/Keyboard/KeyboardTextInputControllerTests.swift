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
}

private final class KeyboardTextDocumentProxySpy: KeyboardTextDocumentProxying {
    var documentContextBeforeInput: String?
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
