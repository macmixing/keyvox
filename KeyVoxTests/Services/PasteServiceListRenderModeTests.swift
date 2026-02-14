import Foundation
import Testing
@testable import KeyVox

struct PasteServiceListRenderModeTests {
    @Test
    func singleLineRolesMapToInlineMode() {
        #expect(PasteService.listRenderMode(forAXRole: "AXTextField") == .singleLineInline)
        #expect(PasteService.listRenderMode(forAXRole: "AXSearchField") == .singleLineInline)
        #expect(PasteService.listRenderMode(forAXRole: "AXComboBox") == .singleLineInline)
    }

    @Test
    func unknownOrMultilineRolesDefaultToMultiline() {
        #expect(PasteService.listRenderMode(forAXRole: "AXTextArea") == .multiline)
        #expect(PasteService.listRenderMode(forAXRole: nil) == .multiline)
    }
}
