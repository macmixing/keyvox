import NaturalLanguage
import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Where a sentence begins, the bar offers words that open a sentence after the one before
/// it, capitalized as the first word of a sentence, and never a name.
final class SentenceOpenerBarTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
    }

    func testOpenersFollowThePreviousSentence() throws {
        let afterGreeting = try bar(after: "Hi! ")
        XCTAssertTrue(afterGreeting.contains("How"), "after a greeting: \(afterGreeting)")
        XCTAssertNotEqual(afterGreeting, try bar(after: "It works. "))
    }

    /// Who the previous sentence was about can open the next one, as on Apple's keyboard.
    func testOpenersCarryTheSubjectOfThePreviousSentence() throws {
        XCTAssertTrue(try bar(after: "She won an award. ").contains("She"))
        XCTAssertTrue(try bar(after: "Can they come? ").contains("They"))
        XCTAssertTrue(try bar(after: "We should go to the beach. ").contains("We"))
    }

    /// A word carries over only when it refers to a person or thing, as "they" brings "They";
    /// a word such as "maybe" or "did" never opens the next sentence for having been typed.
    func testOnlyWordsForPeopleOrThingsCarryOver() throws {
        for text in ["Maybe. ", "Did you jump? ", "Never ring me again! ", "Learn by doing. ", "Tell me more. "] {
            let kinds = wordKinds(in: text)
            for word in try bar(after: text) {
                guard let kind = kinds[word.lowercased()] else { continue }
                XCTAssertEqual(kind, .pronoun, "after \"\(text)\": \(word) carried over")
            }
        }
    }

    func testOpenersAreCapitalizedSentenceStartsWithoutNames() throws {
        for text in ["Hi there. ", "Did it work? ", "Wow! ", "See you\n"] {
            let words = try bar(after: text)
            XCTAssertEqual(words.count, 3, "after \"\(text)\": \(words)")
            XCTAssertTrue(words.allSatisfy { $0.first?.isUppercase == true }, "after \"\(text)\": \(words)")
            XCTAssertFalse(words.contains("Tom"), "after \"\(text)\": \(words)")
        }
    }

    private func bar(after text: String) throws -> [String] {
        let request = PredictiveTypingSession().request(textBeforeCursor: text)
        return try computer.compute(request).bar.items.map(\.text)
    }

    /// Each word of `text`, lowercased, with its lexical class there.
    private func wordKinds(in text: String) -> [String: NLTag] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var kinds: [String: NLTag] = [:]
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .joinContractions]
        ) { tag, range in
            if let tag {
                kinds[text[range].lowercased()] = tag
            }
            return true
        }
        return kinds
    }
}
