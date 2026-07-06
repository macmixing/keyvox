import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class StyleRewriteConfigurationTests: XCTestCase {
    func testNoneStyleReturnsNoRequest() {
        let request = StyleRewriteDictationConfiguration.request(
            for: .none,
            baseText: "Plain dictation."
        )

        XCTAssertNil(request)
    }

    func testPolishedRequestUsesModelTokenWindow() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "Quick note me and Sarah was talking."
        ))

        XCTAssertEqual(request.contextTokenLimit, StyleRewriteDictationConfiguration.modelContextTokenLimit)
        XCTAssertEqual(request.maximumResponseTokens, StyleRewriteDictationConfiguration.modelMaximumGenerationTokenLimit)
        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.polished.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.polishedLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testChillRequestUsesCleanupOnlyStyle() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .chill,
            baseText: "Hey what's up man?"
        ))

        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.chill.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.casualLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testCasualRequestUsesCleanupOnlyStyle() throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .casual,
            baseText: "Hey what's up man?"
        ))

        XCTAssertEqual(request.styleIdentifier, StyleRewriteStyle.casual.styleIdentifier)
        XCTAssertEqual(request.instructions, StyleRewriteDictationConfiguration.casualLoRASystemPrompt)
        XCTAssertTrue(request.promptPrefix.isEmpty)
    }

    func testStyleModelRewriteEligibility() {
        XCTAssertFalse(StyleRewriteStyle.none.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.polished.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.casual.usesModelRewrite)
        XCTAssertTrue(StyleRewriteStyle.chill.usesModelRewrite)
    }
}
