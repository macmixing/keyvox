import Foundation
import XCTest
@testable import KeyVoxCore

final class ListFormattingEngineTests: XCTestCase {
    func testFormatsDetectedList() {
        let engine = ListFormattingEngine()
        let text = "Need to do this one buy groceries two walk dog"

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertTrue(output.contains("1. Buy groceries"))
        XCTAssertTrue(output.contains("2. Walk dog"))
    }

    func testLeavesNonListTextUnchanged() {
        let engine = ListFormattingEngine()
        let text = "This is a normal sentence about version 1.2.3 only."

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertTrue(output == text)
    }

    func testFormatsListWhenNumberingSkipsAhead() {
        let engine = ListFormattingEngine()
        let text = "Need to do this one buy groceries two walk dog four call mom"

        let output = engine.formatIfNeeded(text, renderMode: .multiline)
        XCTAssertTrue(output == "Need to do this:\n\n1. Buy groceries\n2. Walk dog\n4. Call mom")
    }
}
