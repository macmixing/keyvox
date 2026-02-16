import Foundation
import XCTest
@testable import KeyVox

final class PasteServiceListRenderModeTests: XCTestCase {
    func testSingleLineRolesMapToInlineMode() {
        XCTAssertTrue(PasteService.listRenderMode(forAXRole: "AXTextField") == .singleLineInline)
        XCTAssertTrue(PasteService.listRenderMode(forAXRole: "AXSearchField") == .singleLineInline)
        XCTAssertTrue(PasteService.listRenderMode(forAXRole: "AXComboBox") == .singleLineInline)
    }

    func testUnknownOrMultilineRolesDefaultToMultiline() {
        XCTAssertTrue(PasteService.listRenderMode(forAXRole: "AXTextArea") == .multiline)
        XCTAssertTrue(PasteService.listRenderMode(forAXRole: nil) == .multiline)
    }

    func testMessagesBundleOverrideForcesMultiline() {
        XCTAssertTrue(
            PasteService.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.apple.MobileSMS"
            ) == .multiline
        )
    }
}
