import Foundation
import Testing
@testable import KeyVox

struct ListFormattingEngineTests {
    @Test
    func formatsDetectedList() {
        let engine = ListFormattingEngine()
        let text = "Need to do this one buy groceries two walk dog"

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        #expect(output.contains("1. buy groceries"))
        #expect(output.contains("2. walk dog"))
    }

    @Test
    func leavesNonListTextUnchanged() {
        let engine = ListFormattingEngine()
        let text = "This is a normal sentence about version 1.2.3 only."

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        #expect(output == text)
    }
}
