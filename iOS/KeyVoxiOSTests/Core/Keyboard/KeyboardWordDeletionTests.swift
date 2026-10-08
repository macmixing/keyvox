import Foundation
import Testing
@testable import KeyVox_iOS

/// A held delete key deletes whole words the way the system keyboard does: the rest of the
/// word at the cursor, then each earlier word with the spaces or line breaks after it.
struct KeyboardWordDeletionTests {
    @Test func restOfTheWordAtTheCursorIsOneWord() {
        #expect(span(ofWords: 1, endingText: "one two thr") == .init(characterCount: "thr".count, wordCount: 1))
    }

    @Test func wordGoesWithTheSpaceAfterIt() {
        #expect(span(ofWords: 1, endingText: "one two ").characterCount == "two ".count)
        #expect(span(ofWords: 2, endingText: "one two thr").characterCount == "two thr".count)
    }

    @Test func punctuationGoesWithItsWord() {
        #expect(span(ofWords: 1, endingText: "one two, ").characterCount == "two, ".count)
        #expect(span(ofWords: 1, endingText: "one two. ").characterCount == "two. ".count)
    }

    @Test func lineBreaksCountAsSpaces() {
        #expect(span(ofWords: 1, endingText: "one\ntwo\n").characterCount == "two\n".count)
        #expect(span(ofWords: 2, endingText: "one\ntwo\n").characterCount == "one\ntwo\n".count)
    }

    @Test func neverReachesPastTheText() {
        #expect(span(ofWords: 2, endingText: "one") == .init(characterCount: "one".count, wordCount: 1))
        #expect(span(ofWords: 2, endingText: "") == .init(characterCount: 0, wordCount: 0))
    }

    @Test func textInputControllerDeletesTheWordsCharacters() {
        let documentProxy = WordDeletionDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "one two thr"
        var keypresses = 0
        var finishes = 0
        let controller = KeyboardTextInputController(
            documentProxy: documentProxy,
            emitKeypress: { keypresses += 1 }
        )

        #expect(controller.deleteWordsBackward(2) { finishes += 1 } == true)
        #expect(documentProxy.deleteBackwardCallCount == "two thr".count)
        #expect(keypresses == 1)
        #expect(finishes == 1)
    }

    @Test func textInputControllerLeavesSelectionsToCharacterDeletion() {
        let documentProxy = WordDeletionDocumentProxySpy()
        documentProxy.documentContextBeforeInput = "one two"
        documentProxy.selectedText = "two"
        let controller = KeyboardTextInputController(documentProxy: documentProxy, emitKeypress: {})

        #expect(controller.deleteWordsBackward(2) {} == false)
        #expect(documentProxy.deleteBackwardCallCount == 0)
    }

    /// A host that shows only the current line still loses whole words: once the line is gone,
    /// the rest of the words are deleted from the line before it.
    @Test @MainActor func wordsRunOnPastTheStartOfAShownLine() async throws {
        let documentProxy = LineShowingDocumentProxy(lines: ["alpha bravo ", "charlie delta"])
        let controller = KeyboardTextInputController(documentProxy: documentProxy, emitKeypress: {})
        var finished = false

        #expect(controller.deleteWordsBackward(3) { finished = true } == true)
        for _ in 0..<50 where finished == false {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(finished)
        #expect(documentProxy.text == "alpha ")
    }

    private func span(ofWords words: Int, endingText text: String) -> KeyboardWordDeletion.Span {
        KeyboardWordDeletion.span(ofWords: words, endingText: text)
    }
}

private final class WordDeletionDocumentProxySpy: KeyboardTextDocumentProxying {
    var documentContextBeforeInput: String?
    var documentContextAfterInput: String?
    var hasText = false
    var selectedText: String?
    var deleteBackwardCallCount = 0

    func insertText(_ text: String) {}

    func deleteBackward() {
        deleteBackwardCallCount += 1
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {}
}

/// Shows the keyboard only the text since the start of the cursor's line, and nothing once
/// the cursor reaches that start, until the next deletion moves it onto the line before.
private final class LineShowingDocumentProxy: KeyboardTextDocumentProxying {
    private var lines: [String]
    private var isShowingLine = true

    init(lines: [String]) {
        self.lines = lines
    }

    var text: String { lines.joined() }
    var documentContextBeforeInput: String? {
        guard isShowingLine, let line = lines.last, line.isEmpty == false else { return nil }
        return line
    }
    var documentContextAfterInput: String? { nil }
    var hasText: Bool { text.isEmpty == false }
    var selectedText: String? { nil }

    func insertText(_ text: String) {}

    func deleteBackward() {
        if lines.last?.isEmpty == true, lines.count > 1 {
            lines.removeLast()
            isShowingLine = true
        }
        guard var line = lines.popLast(), line.isEmpty == false else { return }
        line.removeLast()
        lines.append(line)
        isShowingLine = line.isEmpty == false
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {}
}
