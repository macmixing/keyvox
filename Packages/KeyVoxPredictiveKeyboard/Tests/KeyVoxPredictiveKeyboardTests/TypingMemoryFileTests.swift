import XCTest
@testable import KeyVoxPredictiveKeyboard

/// What the keyboard learned survives a restart through its file, and a reset counted elsewhere
/// makes an older file restore nothing.
final class TypingMemoryFileTests: XCTestCase {
    private var directory: URL!
    private let start = Date(timeIntervalSince1970: 1_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSavedMemoryRestoresRejectionsWordsAndCapitalsButNotUndos() throws {
        let memory = TypingMemory()
        memory.recordRejection(of: "the", typed: "teh", at: start)
        memory.recordUndo(of: "tea", typed: "rea")
        for previous in ["like", "need"] {
            memory.recordUse(of: "Zorbix", after: previous, at: start)
        }
        memory.recordCapitalUse(of: "Rose", at: start)
        let file = TypingMemoryFile(url: directory.appendingPathComponent("memory.json"))
        try file.save(memory.saved, resetGeneration: 3)

        let restored = TypingMemory(saved: file.load(resetGeneration: 3))
        XCTAssertEqual(restored.saved, memory.saved)
        XCTAssertTrue(restored.rejections.holdsBack("the", of: "teh", at: start))
        XCTAssertFalse(restored.rejections.holdsBack("tea", of: "rea", at: start))
        XCTAssertEqual(restored.learnedWords, memory.learnedWords)
        XCTAssertEqual(restored.learnedVocabulary.capitalForm(of: "rose"), "Rose")
    }

    func testFileSavedBeforeAResetRestoresNothing() throws {
        let memory = TypingMemory()
        memory.recordRejection(of: "the", typed: "teh", at: start)
        let file = TypingMemoryFile(url: directory.appendingPathComponent("memory.json"))
        try file.save(memory.saved, resetGeneration: 3)
        XCTAssertEqual(file.load(resetGeneration: 4), TypingMemory.Saved())
    }

    func testChangesSayWhetherWhatSuggestionsUseChanged() {
        let memory = TypingMemory()
        var changes: [Bool] = []
        memory.onChange = { changes.append($0) }
        memory.recordRejection(of: "the", typed: "teh", at: start)
        memory.recordAcceptance(of: "the", typed: "teh")
        memory.recordAcceptance(of: "the", typed: "teh")
        memory.recordUse(of: "zorbix", after: nil, at: start)
        memory.recordUse(of: "zorbix", after: "like", at: start)
        memory.recordCapitalUse(of: "Rose", at: start)
        memory.recordCapitalUse(of: "Rose", at: start)
        memory.forget("zorbix")
        memory.forget("zorbix")
        memory.forget("Rose")
        XCTAssertEqual(changes, [false, false, false, true, true, false, true, true])
    }
}
