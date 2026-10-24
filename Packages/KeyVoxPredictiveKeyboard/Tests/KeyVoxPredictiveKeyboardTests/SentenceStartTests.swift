import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A word typed after the space that follows a sentence end starts the next sentence, and the
/// quotation marks the quote keys type on either side of that space leave it starting there.
final class SentenceStartTests: XCTestCase {
    private let quoteKeys = [SmartQuotes.doubleQuote, SmartQuotes.apostrophe]
    private let sentenceEnds = ["a.", "a?", "a!"]

    private func typing(_ key: String, after text: String) -> String {
        text + SmartQuotes.text(for: key, after: text)
    }

    func testSentenceStartsAfterTheSpaceThatFollowsASentenceEnd() {
        XCTAssertTrue(TypingTextContext.startsSentence(after: ""))
        XCTAssertTrue(TypingTextContext.startsSentence(after: "a\n"))
        for end in sentenceEnds {
            XCTAssertTrue(TypingTextContext.startsSentence(after: end + " "), "after \(end)")
            XCTAssertFalse(TypingTextContext.startsSentence(after: end), "right after \(end)")
        }
        XCTAssertFalse(TypingTextContext.startsSentence(after: "a "))
        XCTAssertFalse(TypingTextContext.startsSentence(after: "a... "))
    }

    func testOpeningQuoteKeepsTheSentenceStart() {
        for key in quoteKeys {
            for before in ["", "a\n"] + sentenceEnds.map({ $0 + " " }) {
                let text = typing(key, after: before)
                XCTAssertTrue(TypingTextContext.startsSentence(after: text), "after \(text)")
            }
            let midSentence = typing(key, after: "a ")
            XCTAssertFalse(TypingTextContext.startsSentence(after: midSentence), "after \(midSentence)")
        }
    }

    func testClosingQuoteKeepsTheSentenceEnd() {
        for key in quoteKeys {
            for end in sentenceEnds {
                let closed = typing(key, after: typing(key, after: "a ") + end)
                XCTAssertTrue(TypingTextContext.startsSentence(after: closed + " "), "after \(closed)")
                XCTAssertFalse(TypingTextContext.startsSentence(after: closed), "right after \(closed)")
            }
            let closedMidSentence = typing(key, after: typing(key, after: "a ") + "a") + " "
            XCTAssertFalse(TypingTextContext.startsSentence(after: closedMidSentence), "after \(closedMidSentence)")
        }
    }
}
