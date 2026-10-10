import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A word the keyboard does not know is learned on its second use wherever it was typed, offered
/// once written twice the way it was first written, given the user's first capitals once those
/// outnumber its other uses, and first after a word it followed twice, as on the system
/// keyboard. Forgetting it starts its count over.
final class LearnedWordsTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testWordIsLearnedOnItsSecondUseWhereverItWasTyped() {
        var words = LearnedWords()
        XCTAssertFalse(words.recordUse(of: "zorbix", after: "like", at: start))
        XCTAssertFalse(words.contains("zorbix"))
        XCTAssertTrue(words.recordUse(of: "zorbix", after: "need", at: start))
        XCTAssertTrue(words.contains("Zorbix"))
        XCTAssertEqual(Array(words.learned.keys), ["zorbix"])
        XCTAssertFalse(words.recordUse(of: "zorbix", after: "use", at: start), "nothing suggestions use changed")
    }

    func testBarOffersTheWordOnceWrittenTwiceTheWayItWasFirstWritten() {
        XCTAssertEqual(uses(["zorbix", "Zorbix", "Zorbix"]).isOffered, false, "first written without capitals once")
        XCTAssertEqual(uses(["Zorbix", "zorbix"]).isOffered, false)
        XCTAssertEqual(uses(["Zorbix", "ZORBIX"]).isOffered, true, "both with capitals")
        XCTAssertEqual(uses(["zorbix", "zorbix"]).isOffered, true)
        XCTAssertEqual(uses(["Zorbix", "zorbix"]).firstForm, "Zorbix")
    }

    func testTypingWithoutCapitalsGetsTheFirstCapitalsOnceTheyOutnumberTheOtherUses() {
        XCTAssertFalse(uses(["Zorbix"]).keepsCapitals)
        XCTAssertTrue(uses(["Zorbix", "Zorbix"]).keepsCapitals)
        XCTAssertFalse(uses(["zorbix", "zorbix", "Zorbix", "Zorbix"]).keepsCapitals)
        XCTAssertTrue(uses(["zorbix", "zorbix", "Zorbix", "Zorbix", "Zorbix"]).keepsCapitals)
        XCTAssertEqual(uses(["Zorbix", "ZORBIX"]).capitalForm, "Zorbix", "the first capitals stay")
    }

    func testWordComesFirstAfterAWordItFollowedTwice() {
        var words = LearnedWords()
        words.recordUse(of: "zorbix", after: "like", at: start)
        words.recordUse(of: "zorbix", after: "need", at: start)
        XCTAssertEqual(words.uses["zorbix"]?.oftenFollowed, [])
        XCTAssertTrue(words.recordUse(of: "zorbix", after: "Like", at: start))
        XCTAssertEqual(words.uses["zorbix"]?.oftenFollowed, ["like"])
        words.recordUse(of: "zorbix", after: nil, at: start)
        words.recordUse(of: "zorbix", after: nil, at: start)
        XCTAssertEqual(words.uses["zorbix"]?.oftenFollowed, ["like", ContextLanguageScorer.sentenceStart])
    }

    func testForgettingALearnedWordStartsItsCountOver() {
        var words = LearnedWords()
        for _ in 0..<LearnedWords.usesToLearn {
            words.recordUse(of: "zorbix", after: nil, at: start)
        }
        XCTAssertTrue(words.forget("zorbix"))
        XCTAssertFalse(words.contains("zorbix"))
        words.recordUse(of: "zorbix", after: nil, at: start)
        XCTAssertFalse(words.contains("zorbix"))
    }

    func testOnlyLearnedWordsCanBeForgotten() {
        var words = LearnedWords()
        words.recordUse(of: "zorbix", after: nil, at: start)
        XCTAssertFalse(words.forget("zorbix"))
        XCTAssertEqual(words.uses.count, 1)
    }

    func testWordsUsedLongestAgoGoFirstPastCapacity() {
        var words = LearnedWords()
        for index in 0...LearnedWords.capacity {
            words.recordUse(of: "word\(index)", after: nil, at: start.addingTimeInterval(TimeInterval(index)))
        }
        XCTAssertEqual(words.uses.count, LearnedWords.capacity)
        XCTAssertNil(words.uses["word0"])
    }

    func testLeastFollowedWordsBeforeGoFirstPastCapacity() {
        var words = LearnedWords()
        words.recordUse(of: "zorbix", after: "like", at: start)
        words.recordUse(of: "zorbix", after: "like", at: start)
        for index in 0..<LearnedWords.previousWordCapacity {
            words.recordUse(of: "zorbix", after: "word\(index)", at: start)
        }
        XCTAssertEqual(words.uses["zorbix"]?.previousWords.count, LearnedWords.previousWordCapacity)
        XCTAssertEqual(words.uses["zorbix"]?.previousWords["like"], 2)
    }

    /// The word's use after `forms`, written in order.
    private func uses(_ forms: [String]) -> LearnedWords.Use {
        var words = LearnedWords()
        for form in forms {
            words.recordUse(of: form, after: nil, at: start)
        }
        return words.uses[PersonalVocabulary.key(forms[0])]!
    }
}
