import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Deleting into a word the keyboard changed, or past it, even after typing on, as the system
/// keyboard was seen handling it: the change is held back while the keyboard runs, and the word
/// typed in its place keeps as typed. Nothing is saved or learned, so the change applies again
/// once the keyboard restarts, or once the user deletes on past the word typed in its place. The
/// pronoun "I"'s capital is not held back.
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

    /// Typing on after a change and deleting back into it holds the change back, also after a
    /// comma.
    func testDeletingBackIntoAChangeAfterTypingOnHoldsItBack() throws {
        let typing = typing(TypingMemory())
        try typing.words(["so", "recieve"])
        typing.type("the")
        typing.delete("the".count + "eive ".count)
        typing.type("ieve")
        try typing.space()
        try typing.words(["recieve"])
        XCTAssertEqual(typing.text, "so recieve recieve ")

        let comma = self.typing(TypingMemory())
        try comma.words(["so"])
        comma.type("recieve")
        try comma.end(with: ",")
        comma.type(" ")
        XCTAssertEqual(comma.text, "so receive, ")
        comma.delete(", ".count + "eive".count)
        comma.type("ieve")
        try comma.end(with: ",")
        XCTAssertEqual(comma.text, "so recieve,")
    }

    /// Deleting back through a later change into an earlier one holds both back.
    func testDeletingIntoTheEarlierOfTwoChangesHoldsBoth() throws {
        let typing = typing(TypingMemory())
        try typing.words(["so", "recieve", "teh"])
        XCTAssertEqual(typing.text, "so receive the ")
        typing.delete("the ".count + "eive ".count)
        typing.type("ieve")
        try typing.space()
        try typing.words(["teh", "recieve"])
        XCTAssertEqual(typing.text, "so recieve teh recieve ")
    }

    /// Deleting on past the start of a change holds it back, and the word typed in its place
    /// keeps.
    func testDeletingPastAChangeHoldsItBack() throws {
        let typing = typing(TypingMemory())
        try typing.words(["so", "the", "recieve"])
        typing.delete(" receive ".count)
        try typing.space()
        try typing.words(["recieve", "recieve"])
        XCTAssertEqual(typing.text, "so the recieve recieve ")
    }

    /// A word kept because its change was held back is not learned, so the change applies again
    /// once the keyboard restarts.
    func testWordKeptForAHeldBackChangeIsNotLearned() throws {
        let memory = TypingMemory()
        let typing = typing(memory)
        try typing.words(["so", "recieve"])
        typing.delete("eive ".count)
        typing.type("ieve")
        try typing.space()
        try typing.words(["recieve", "recieve"])
        XCTAssertFalse(memory.learnedWords.contains("recieve"))

        let restarted = self.typing(TypingMemory(saved: memory.saved))
        try restarted.words(["so", "recieve"])
        XCTAssertEqual(restarted.text, "so receive ")
    }

    /// Clearing the text, or typing a new text that starts as an earlier one did, turns no change
    /// down.
    func testClearingOrRetypingTheStartOfATextHoldsNothingBack() throws {
        let typing = typing(TypingMemory())
        try typing.words(["so", "recieve"])
        typing.clear()
        try typing.words(["so", "recieve"])
        XCTAssertEqual(typing.text, "so receive ")
    }

    /// A change deleted into is held back only for the word typed in the same capitals until the
    /// user keeps the word for it, and then in any capitals; the word typed first after emptying
    /// the text is not typed in its place.
    func testHeldBackChangeReachesOtherCapitalsOnceTheWordIsKept() throws {
        let typing = typing(TypingMemory())
        try typing.words(["so", "the", "recieve"])
        typing.delete(typing.text.count)
        try typing.words(["Recieve"])
        XCTAssertEqual(typing.text, "Receive ")
        try typing.words(["recieve"])
        XCTAssertEqual(typing.text, "Receive recieve ")
        typing.clear()
        try typing.words(["Recieve"])
        XCTAssertEqual(typing.text, "Recieve ")
    }

    /// The word typed first after deleting past a change keeps as typed wherever it starts, even
    /// in other capitals.
    func testWordTypedFirstAfterDeletingPastAChangeKeeps() throws {
        let typing = typing(TypingMemory())
        typing.type("Ok")
        try typing.end(with: ".")
        typing.type(" ")
        try typing.words(["the", "recieve"])
        XCTAssertEqual(typing.text, "Ok. the receive ")
        typing.delete("the receive ".count)
        try typing.words(["Recieve"])
        XCTAssertEqual(typing.text, "Ok. Recieve ")
    }

    /// Deleting on past the start of the word typed in place of a change lets the change apply
    /// again; deleting back only to its start does not.
    func testDeletingPastTheWordTypedInPlaceLetsTheChangeApplyAgain() throws {
        let past = typing(TypingMemory())
        try past.words(["so", "the", "recieve"])
        past.delete("eive ".count)
        past.type("ieve")
        try past.space()
        past.delete("he recieve ".count)
        past.type("he")
        try past.space()
        try past.words(["recieve"])
        XCTAssertEqual(past.text, "so the receive ")

        let toStart = typing(TypingMemory())
        try toStart.words(["so", "recieve"])
        toStart.delete("eive ".count)
        toStart.type("ieve")
        try toStart.space()
        toStart.delete("recieve ".count)
        try toStart.words(["recieve"])
        XCTAssertEqual(toStart.text, "so recieve ")
    }

    /// The word typed in place of a change keeps as typed when it is a slip from the word typed
    /// there or from the change, and keeps later too; another word is corrected as usual.
    func testWordTypedInPlaceKeepsOnlyWhenASlipFromTheChange() throws {
        let slip = typing(TypingMemory())
        try slip.words(["so", "recieve"])
        slip.delete("eive ".count)
        slip.type("ive")
        try slip.space()
        try slip.words(["recive"])
        XCTAssertEqual(slip.text, "so recive recive ")

        let other = typing(TypingMemory())
        try other.words(["so", "recieve"])
        other.delete("eive ".count)
        other.type("cent")
        try other.space()
        XCTAssertEqual(other.text, "so recent ")
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

        /// Empties the text at once, as a field's clear button does.
        func clear() {
            text = ""
            session.textDidChange(textBeforeCursor: text)
        }

        func delete(_ count: Int) {
            for _ in 0..<count {
                text.removeLast()
                session.textDidChange(textBeforeCursor: text)
            }
        }

        func space() throws {
            try end(with: " ")
        }

        /// Ends the word with `separator`, as space or punctuation does.
        func end(with separator: String) throws {
            let result = try computer.compute(session.request(textBeforeCursor: text))
            let revision = try session.revisionRequest(textBeforeCursor: text, result: result)
                .flatMap { try computer.revision(for: $0) }
            let edit = session.wordBoundaryEdit(separator: separator, textBeforeCursor: text, result: result, revision: revision)
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
