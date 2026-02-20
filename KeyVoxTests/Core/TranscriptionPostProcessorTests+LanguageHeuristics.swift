import Foundation
import XCTest
@testable import KeyVox

@MainActor
extension TranscriptionPostProcessorTests {
    func testCollapsesSingleCharacterSpamRun() {
        let processor = TranscriptionPostProcessor()
        let spam = String(repeating: "j", count: 140)

        let output = processor.process(
            spam,
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "J")
    }
    func testCollapsesUnicodeCircleCharacterSpamRun() {
        let processor = TranscriptionPostProcessor()
        let spam = String(repeating: "◯", count: 120)

        let output = processor.process(
            spam,
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "◯")
    }
    func testRandomizedCharacterSpamRunsAreCollapsed() {
        let processor = TranscriptionPostProcessor()
        var rng = SeededGenerator(state: 0xC0FFEE123456789)
        let characters = Array("abcdefghijklmnopqrstuvwxyz0123456789@#$_-+=*")
            + ["◯", "○", "◎", "●", "◉", "◌"]

        for _ in 0..<60 {
            let character = characters[Int.random(in: 0..<characters.count, using: &rng)]
            let runLength = Int.random(in: 16...220, using: &rng)
            let spam = String(repeating: String(character), count: runLength)

            let output = processor.process(
                "prefix \(spam) suffix",
                dictionaryEntries: [],
                renderMode: .singleLineInline
            )

            XCTAssertFalse(
                containsCharacterSpamRun(output),
                "Expected spam run to be collapsed for character='\(character)' length=\(runLength). Output=\(output)"
            )
            let normalizedOutput = output.lowercased()
            XCTAssertTrue(normalizedOutput.contains("prefix"))
            XCTAssertTrue(normalizedOutput.contains("suffix"))
        }
    }
    func testCollapsesExcessiveLaughterSpamRuns() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "haha haha haha haha haha haha haha haha haha haha ha",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Haha haha haha haha")
    }
    func testPreservesShortLaughterRunsWithoutSpamCollapse() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "haha haha haha",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Haha haha haha")
    }
    func testExpandsHahaHaTripletShorthand() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "haha ha",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertEqual(output, "Ha ha ha")
    }
    func testNormalizesHaHaToHaha() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Ha ha that was funny",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Haha that was funny")
    }
    func testKeepsBetweenColonPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Let's pick between colon McDonalds or Burger King",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Let's pick between colon McDonalds or Burger King")
    }
    func testKeepsBetweenColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Let's pick between Colin McDonalds or Burger King",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Let's pick between Colin McDonalds or Burger King")
    }
    func testNormalizesCommaDelimitedColonPhraseToPunctuation() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm going to the store, colon, to buy some groceries.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I'm going to the store: To buy some groceries.")
    }
    func testNormalizesCommaDelimitedLowercaseColinPhraseToPunctuation() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Example, colin, exhibit A",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Example: Exhibit A")
    }
    func testRemovesTerminalPeriodForShortStandaloneColonAssociation() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Example, colon, exhibit A.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Example: Exhibit A")
    }
    func testKeepsCommaDelimitedCapitalizedColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm going to the store, Colin, to buy some groceries.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I'm going to the store, Colin, to buy some groceries.")
    }
    func testKeepsCommaDelimitedCollinNameLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I met, Collin, yesterday at lunch.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I met, Collin, yesterday at lunch.")
    }
    func testColonNormalizationStaysCompatibleWithWebsiteNormalization() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Please visit www.KeyVox.app, colon, support docs",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Please visit www.keyvox.app: Support docs")
    }
    func testColonNormalizationStaysCompatibleWithDictionaryBrandWords() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "Cueboard")]

        let output = processor.process(
            "Brand update, colon, cue board roadmap",
            dictionaryEntries: entries,
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Brand update: Cueboard roadmap")
    }
    func testColonNormalizationStaysCompatibleWithListFormatting() {
        let processor = TranscriptionPostProcessor()
        let entries = [DictionaryEntry(phrase: "Cueboard")]

        let output = processor.process(
            "Project notes, colon, one cue board design two website launch",
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        XCTAssertTrue(output.hasPrefix("Project notes:"))
        XCTAssertTrue(output.contains("1. Cueboard design"))
        XCTAssertTrue(output.contains("2. Website launch"))
    }
    func testKeepsStandaloneColonWordWithoutContext() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "The word colon appears here",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "The word colon appears here")
    }
    func testKeepsTerminalCommaDelimitedColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Next task, Colin.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Next task, Colin.")
    }
    func testDoesNotRewriteSingleWordGreetingColin() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Hi, Colin.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "Hi, Colin.")
    }
    func testNormalizesHoleInOneIdiom() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I was golfing last week and I got a hole in one because there were opponents ahead of me",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertTrue(output == "I was golfing last week and I got a hole-in-one because there were opponents ahead of me")
    }
    func testHoleInOneWithTwoInProseDoesNotTriggerListFormatting() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I was golfing last week and I got a hole in one because there were two opponents ahead of me",
            dictionaryEntries: [],
            renderMode: .multiline
        )

        XCTAssertTrue(output == "I was golfing last week and I got a hole-in-one because there were two opponents ahead of me")
        XCTAssertFalse(output.contains("\n1. "))
        XCTAssertFalse(output.contains("\n2. "))
    }

    private func containsCharacterSpamRun(_ text: String) -> Bool {
        let regex = try! NSRegularExpression(pattern: #"([^\s])\1{15,}"#, options: [])
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 2862933555777941757 &+ 3037000493
        return state
    }
}
