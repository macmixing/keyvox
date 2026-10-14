import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Deleting into a word the keyboard changed, as the system keyboard was seen handling it: the
/// change is held back while the keyboard runs, and the word typed in its place keeps as typed.
/// Nothing is saved, so the change applies again once the keyboard restarts. The pronoun "I"'s
/// capital is not held back.
final class DeletedIntoCorrectionTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
    }

    /// "I male mistakes": the next word made "male" "make"; deleting back to "ma" and typing
    /// "le" and "mistakes" again keeps "male", in a new text too, until the keyboard restarts.
    func testDeletingIntoAWordTheNextWordChangedHoldsTheChangeBack() throws {
        let memory = TypingMemory()
        let typing = typing(memory)
        try typing.words(["i", "male", "mistakes"])
        XCTAssertEqual(typing.text, "I make mistakes ")

        typing.delete("ke mistakes ".count)
        typing.type("le")
        try typing.space()
        try typing.words(["mistakes"])
        XCTAssertEqual(typing.text, "I male mistakes ")

        let newText = self.typing(memory)
        try newText.words(["i", "male", "mistakes"])
        XCTAssertEqual(newText.text, "I male mistakes ")

        let restarted = self.typing(TypingMemory(saved: memory.saved))
        try restarted.words(["i", "male", "mistakes"])
        XCTAssertEqual(restarted.text, "I make mistakes ")
    }

    /// "so recieve": space made it "receive"; deleting back to "rec" and typing "ieved" keeps
    /// "recieved", and "recieve" typed later keeps too.
    func testWordTypedInPlaceOfAChangeKeepsAndTheChangeIsHeldBack() throws {
        let typing = typing(TypingMemory())
        try typing.words(["so", "recieve"])
        XCTAssertEqual(typing.text, "so receive ")

        typing.delete("eive ".count)
        typing.type("ieved")
        try typing.space()
        XCTAssertEqual(typing.text, "so recieved ")
        try typing.words(["recieve"])
        XCTAssertEqual(typing.text, "so recieved recieve ")
    }

    /// "so i": space made it "I"; deleting it and typing "i" keeps "i" that once, and the next
    /// "i" becomes "I" again.
    func testPronounTypedBackKeepsOnlyThatOnce() throws {
        let typing = typing(TypingMemory())
        try typing.words(["so", "i"])
        XCTAssertEqual(typing.text, "so I ")

        typing.delete("I ".count)
        typing.type("i")
        try typing.space()
        XCTAssertEqual(typing.text, "so i ")
        try typing.words(["i"])
        XCTAssertEqual(typing.text, "so i I ")
    }

    /// Deleting only the space after a change holds nothing back.
    func testDeletingOnlyTheSpaceHoldsNothingBack() throws {
        let typing = typing(TypingMemory())
        try typing.words(["so", "recieve"])
        typing.delete(" ".count)
        try typing.space()
        try typing.words(["recieve"])
        XCTAssertEqual(typing.text, "so receive receive ")
    }

    private func typing(_ memory: TypingMemory) -> Typing {
        Typing(computer: computer, session: PredictiveTypingSession(memory: memory))
    }

    /// Types into a text as the keyboard does: one letter or deletion at a time, telling the
    /// session of each change, and space applying the session's edit with the revision of the
    /// word before.
    private final class Typing {
        let computer: PredictionComputer
        let session: PredictiveTypingSession
        private(set) var text = ""

        init(computer: PredictionComputer, session: PredictiveTypingSession) {
            self.computer = computer
            self.session = session
        }

        func type(_ letters: String) {
            for letter in letters {
                text.append(letter)
                session.textDidChange(textBeforeCursor: text)
            }
        }

        func delete(_ count: Int) {
            for _ in 0..<count {
                text.removeLast()
                session.textDidChange(textBeforeCursor: text)
            }
        }

        func space() throws {
            let result = try computer.compute(session.request(textBeforeCursor: text))
            let revision = try session.revisionRequest(textBeforeCursor: text, result: result)
                .flatMap { try computer.revision(for: $0) }
            let edit = session.wordBoundaryEdit(separator: " ", textBeforeCursor: text, result: result, revision: revision)
            text = String(text.dropLast(edit.deleteCount)) + edit.insertText
            session.textDidChange(textBeforeCursor: text)
        }

        func words(_ words: [String]) throws {
            for word in words {
                type(word)
                try space()
            }
        }
    }
}
