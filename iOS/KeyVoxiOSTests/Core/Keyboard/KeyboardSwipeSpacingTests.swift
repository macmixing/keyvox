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

    @Test func oneSpaceAfterAWordSwipedBeforeAnotherWordIsAPlainSpace() throws {
        let keyboard = SwipeSpacingKeyboard(text: "a dog", cursorBefore: "dog")
        try keyboard.swipe("big")
        #expect(keyboard.text == "a big dog")
        keyboard.tapSpace()
        #expect(keyboard.text == "a big  dog")
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

    @Test func movingTheCursorToTheSameWordEndsTheSwipedWord() throws {
        let keyboard = SwipeSpacingKeyboard(text: "hello ")
        try keyboard.swipe("hello")
        #expect(keyboard.text == "hello hello")
        #expect(keyboard.hasTypedWordInProgress == false)
        keyboard.moveCursor(by: -" hello".count)
        #expect(keyboard.hasTypedWordInProgress)
    }

    @Test func anotherFieldEndingWithTheSameWordEndsTheSwipedWord() throws {
        let keyboard = SwipeSpacingKeyboard()
        try keyboard.swipe("hello")
        #expect(keyboard.hasTypedWordInProgress == false)
        keyboard.switchToAnotherFieldWithTheSameText()
        #expect(keyboard.hasTypedWordInProgress)
    }
}

/// The keyboard's swipe and space paths over a field: a swipe ends a typed word in progress, then
/// its word goes in through the prediction coordinator; space goes in through the word boundary the
/// keyboard applies itself, or the text input controller's space key, double-space period included,
/// when the regular path types it.
@MainActor
private final class SwipeSpacingKeyboard {
    private let document: SwipeSpacingDocumentProxy
    private let coordinator: KeyboardPredictionCoordinator
    private let input: KeyboardTextInputController

    var text: String { document.text }
    var hasTypedWordInProgress: Bool { coordinator.hasTypedWordInProgress() }

    init(text: String = "", cursorBefore followingText: String = "") {
        let document = SwipeSpacingDocumentProxy(text: text, cursorBefore: followingText)
        let coordinator = KeyboardPredictionCoordinator(
            memory: TypingMemory(),
            textBeforeCursor: { document.documentContextBeforeInput },
            selectedText: { document.selectedText },
            textAfterCursor: { document.documentContextAfterInput },
            documentIdentifier: { document.identifier }
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
        if let edit = coordinator.appliedWordBoundaryEdit(separator: " ", allowsAutocorrection: true) {
            input.apply(edit)
        } else {
            var symbolPage = KeyboardSymbolPage.letters
            input.handleKeyActivation(.space, symbolPage: &symbolPage)
        }
        coordinator.textDidChange()
    }

    /// Moves the cursor as the host would, reporting the change.
    func moveCursor(by offset: Int) {
        document.adjustTextPosition(byCharacterOffset: offset)
        coordinator.textDidChange()
    }

    /// Another field of the same kind takes the keyboard with the same text around the cursor.
    func switchToAnotherFieldWithTheSameText() {
        document.identifier = UUID()
        coordinator.textDidChange()
    }
}

/// A field's text with a cursor in it.
private final class SwipeSpacingDocumentProxy: KeyboardTextDocumentProxying {
    private(set) var text: String
    private var cursor: String.Index
    var identifier = UUID()

    init(text: String, cursorBefore followingText: String) {
        self.text = text
        cursor = text.index(text.endIndex, offsetBy: -followingText.count)
    }

    var documentContextBeforeInput: String? { String(text[..<cursor]) }
    var documentContextAfterInput: String? { String(text[cursor...]) }
    var hasText: Bool { text.isEmpty == false }
    var selectedText: String? { nil }

    func insertText(_ inserted: String) {
        let offset = text.distance(from: text.startIndex, to: cursor) + inserted.count
        text.insert(contentsOf: inserted, at: cursor)
        cursor = text.index(text.startIndex, offsetBy: offset)
    }

    func deleteBackward() {
        guard cursor > text.startIndex else { return }
        let offset = text.distance(from: text.startIndex, to: cursor) - 1
        text.remove(at: text.index(before: cursor))
        cursor = text.index(text.startIndex, offsetBy: offset)
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        let position = min(max(0, text.distance(from: text.startIndex, to: cursor) + offset), text.count)
        cursor = text.index(text.startIndex, offsetBy: position)
    }
}
