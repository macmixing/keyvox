import Foundation
import XCTest
@testable import KeyVox

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
}
