import Foundation
import Testing
@testable import KeyVox

@MainActor
struct TranscriptionPostProcessorTests {
    @Test
    func appliesDictionaryCasingBeforeListFormatting() {
        let processor = TranscriptionPostProcessor()
        let entries = [
            DictionaryEntry(phrase: "Cueboard"),
        ]

        let output = processor.process(
            "Okay one cueboard two cueboard",
            dictionaryEntries: entries,
            renderMode: .multiline
        )

        #expect(output.contains("1. Cueboard"))
        #expect(output.contains("2. Cueboard"))
    }

    @Test
    func singleLineModeCollapsesWhitespace() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "Hello     world",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        #expect(output == "Hello world")
    }

    @Test
    func emptyInputReturnsEmpty() {
        let processor = TranscriptionPostProcessor()
        let output = processor.process("", dictionaryEntries: [], renderMode: .multiline)
        #expect(output.isEmpty)
    }

    @Test
    func normalizesCompactAndDottedTimesWithMeridiem() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "315 a.m. 317AM 4.19pm",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        #expect(output == "3:15 AM 3:17 AM 4:19 PM")
    }

    @Test
    func preservesDaypartPhrasingWhileFixingTimeShape() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I got there at 418 in the morning and left at 4.19 in the evening",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        #expect(output == "I got there at 4:18 in the morning and left at 4:19 in the evening")
    }

    @Test
    func preservesDaypartPhrasingForHyphenSeparatedTimes() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I think maybe 3-15 in the evening?",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        #expect(output == "I think maybe 3:15 in the evening?")
    }

    @Test
    func normalizesTerminalAndAsFuzzyAm() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "415-AND. 315 and",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        #expect(output == "4:15 AM. 3:15 AM")
    }

    @Test
    func doesNotTreatConjunctionAndAsMeridiem() {
        let processor = TranscriptionPostProcessor()

        let output = processor.process(
            "I said 415 and 530 in the afternoon",
            dictionaryEntries: [],
            renderMode: .singleLineInline
        )

        #expect(output == "I said 415 and 5:30 in the afternoon")
    }
}
