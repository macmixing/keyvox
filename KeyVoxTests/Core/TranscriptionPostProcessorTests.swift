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
}
