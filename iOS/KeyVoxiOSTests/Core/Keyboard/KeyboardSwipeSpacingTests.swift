import Foundation
import KeyVoxPredictiveKeyboard
import Testing
@testable import KeyVox_iOS

/// Spacing around swiped words, as measured on the system keyboard
/// (`~/KeyVoxLanguageData/swipe/apple-swipe-spacing/`): a swiped word goes in with no space after
/// it, one space tapped after it is a plain space, and a word swiped right after it goes in after a
/// space.
@MainActor
struct KeyboardSwipeSpacingTests {
    @Test func aSwipedWordGoesInWithNoSpaceAfterIt() throws {
        let keyboard = SwipeSpacingKeyboard()
        try keyboard.swipe("hello")
        #expect(keyboard.text == "hello")
    }

    @Test func oneSpaceAfterASwipedWordIsAPlainSpace() throws {
        let keyboard = SwipeSpacingKeyboard()
        try keyboard.swipe("hello")
        keyboard.tapSpace()
        #expect(keyboard.text == "hello ")
    }

    @Test func aWordSwipedRightAfterASwipedWordGoesInAfterASpace() throws {
        let keyboard = SwipeSpacingKeyboard()
        try keyboard.swipe("hello")
        try keyboard.swipe("there")
        #expect(keyboard.text == "hello there")
    }

    @Test func aSwipeGetsNoSpaceOfItsOwnAfterASpace() throws {
        let typed = SwipeSpacingKeyboard(text: "hello ")
        try typed.swipe("there")
        #expect(typed.text == "hello there")

        let swiped = SwipeSpacingKeyboard()
        try swiped.swipe("hello")
        swiped.tapSpace()
        try swiped.swipe("there")
        #expect(swiped.text == "hello there")
    }

    @Test func twoSpacesTypedAfterASwipedWordStillTypeAPeriod() throws {
        let keyboard = SwipeSpacingKeyboard()
        try keyboard.swipe("hello")
        keyboard.tapSpace()
        keyboard.tapSpace()
        #expect(keyboard.text == "hello. ")
    }
}

/// The keyboard's swipe and space paths over a field: a swipe ends a typed word in progress, then
/// its word goes in through the prediction coordinator; space goes in through the word boundary,
/// or the text input controller's space key, double-space period included, when that inserts only
/// the separator.
@MainActor
private final class SwipeSpacingKeyboard {
    private let document: SwipeSpacingDocumentProxy
    private let coordinator: KeyboardPredictionCoordinator
    private let input: KeyboardTextInputController

    var text: String { document.text }

    init(text: String = "") {
        let document = SwipeSpacingDocumentProxy(text: text)
        let coordinator = KeyboardPredictionCoordinator(
            memory: TypingMemory(),
            textBeforeCursor: { document.documentContextBeforeInput },
            selectedText: { document.selectedText },
            textAfterCursor: { document.documentContextAfterInput },
            documentIdentifier: { nil }
        )
        coordinator.updateGeometry(KeyboardSwipeTestPath.letterKeys, keyboardSize: KeyboardSwipeTestPath.keyboardSize)
        coordinator.reset()
        self.document = document
        self.coordinator = coordinator
        input = KeyboardTextInputController(
            documentProxy: document,
            emitKeypress: {},
            willEdit: { coordinator.finishPendingSwipe() },
            didEdit: { coordinator.textWasEdited() }
        )
    }

    func swipe(_ word: String) throws {
        if coordinator.hasTypedWordInProgress() {
            input.apply(coordinator.wordBoundaryEdit(separator: " ", allowsAutocorrection: true))
            coordinator.textDidChange()
        }
        coordinator.decodeSwipe(try KeyboardSwipeTestPath.through(word), wordCase: .asSpelled) { [input, coordinator] edit in
            input.apply(edit)
            coordinator.textDidChange()
        }
        coordinator.finishPendingSwipe()
    }

    func tapSpace() {
        let edit = coordinator.wordBoundaryEdit(separator: " ", allowsAutocorrection: true)
        if edit.deleteCount > 0 {
            input.apply(edit)
        } else {
            var symbolPage = KeyboardSymbolPage.letters
            input.handleKeyActivation(.space, symbolPage: &symbolPage)
        }
        coordinator.textDidChange()
    }
}

/// A field's text with the cursor at its end.
private final class SwipeSpacingDocumentProxy: KeyboardTextDocumentProxying {
    private(set) var text: String

    init(text: String) {
        self.text = text
    }

    var documentContextBeforeInput: String? { text }
    var documentContextAfterInput: String? { nil }
    var hasText: Bool { text.isEmpty == false }
    var selectedText: String? { nil }

    func insertText(_ text: String) {
        self.text += text
    }

    func deleteBackward() {
        guard text.isEmpty == false else { return }
        text.removeLast()
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {}
}
