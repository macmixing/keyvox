import Foundation
import XCTest
@testable import KeyVox
import KeyVoxCore

final class PasteServiceListRenderModeTests: XCTestCase {
    func testSingleLineRolesMapToInlineMode() {
        assertListRenderMode(PasteService.listRenderMode(forAXRole: "AXTextField"), equals: .singleLineInline)
        assertListRenderMode(PasteService.listRenderMode(forAXRole: "AXSearchField"), equals: .singleLineInline)
        assertListRenderMode(PasteService.listRenderMode(forAXRole: "AXComboBox"), equals: .singleLineInline)
    }

    func testUnknownOrMultilineRolesDefaultToMultiline() {
        assertListRenderMode(PasteService.listRenderMode(forAXRole: "AXTextArea"), equals: .multiline)
        assertListRenderMode(PasteService.listRenderMode(forAXRole: nil), equals: .multiline)
    }

    func testMessagesBundleOverrideForcesMultiline() {
        assertListRenderMode(
            PasteService.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.apple.MobileSMS"
            ),
            equals: .multiline
        )
    }

    private func assertListRenderMode(_ actual: ListRenderMode, equals expected: ListRenderMode) {
        switch (actual, expected) {
        case (.multiline, .multiline), (.singleLineInline, .singleLineInline):
            XCTAssertTrue(true)
        default:
            XCTFail("Unexpected list render mode")
        }
    }
}
