import Foundation
import XCTest
@testable import KeyVox

@MainActor
extension TranscriptionPostProcessorTests {
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
    func testKeepsCommaDelimitedColonPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm going to the store, colon, to buy some groceries.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I'm going to the store, colon, to buy some groceries.")
    }
    func testKeepsCommaDelimitedColinPhraseLiteral() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I'm going to the store, Colin, to buy some groceries.",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        XCTAssertTrue(output == "I'm going to the store, Colin, to buy some groceries.")
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
}
