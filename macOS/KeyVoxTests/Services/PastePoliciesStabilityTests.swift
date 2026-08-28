import Foundation
import XCTest
@testable import KeyVox
import KeyVoxCore

final class PastePoliciesStabilityTests: XCTestCase {
    func testMenuTrustPolicyMatchesPreFixBehavior() {
        XCTAssertTrue(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.apple.MobileSMS")
        )
        XCTAssertTrue(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.apple.iWork.Numbers")
        )

        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: nil)
        )
        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.microsoft.VSCode")
        )
        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.openai.codex")
        )
        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.google.antigravity")
        )
        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.exafunction.windsurf")
        )
    }

    func testQuillBlankDOMClassDetection() {
        XCTAssertTrue(
            PasteAXInspector.containsQuillBlankDOMClass(["ql-editor", "textarea", "ql-blank"])
        )
        XCTAssertFalse(
            PasteAXInspector.containsQuillBlankDOMClass(["ql-editor", "textarea"])
        )
    }

    func testPlaceholderDOMClassDetection() {
        XCTAssertTrue(
            PasteAXInspector.containsPlaceholderDOMClass(["textarea", "new-input-ui", "placeholder"])
        )
        XCTAssertFalse(
            PasteAXInspector.containsPlaceholderDOMClass(["textarea", "new-input-ui"])
        )
    }

    func testRepeatedTextAfterCaretIsNotTreatedAsTrailingNewline() {
        XCTAssertFalse(
            PasteAXInspector.shouldTreatTrailingValueNewlineAsPrecedingCaret(
                rangeText: "abc",
                value: "abcabc\n",
                caretLocation: 3
            )
        )
    }

    func testOnlyNewlineRangeAtCaretIsTreatedAsInsertionBoundary() {
        XCTAssertTrue(PasteAXInspector.isNewlineRangeAtCaret("\n"))
        XCTAssertFalse(PasteAXInspector.isNewlineRangeAtCaret("a"))
    }

    func testNewlineAtCaretUsesMatchingInsertionLine() {
        XCTAssertTrue(
            PasteAXInspector.shouldTreatNewlineRangeAtCaret(
                "\n",
                insertionLine: 8,
                caretIndexLine: 8
            )
        )
    }

    func testValueConfirmedNewlineAfterCaretDoesNotOverridePreviousCharacter() {
        XCTAssertFalse(
            PasteAXInspector.shouldTreatNewlineRangeAtCaret(
                "\n",
                rangeText: "ab",
                value: "ab\ncd",
                caretLocation: 2,
                insertionLine: 3,
                caretIndexLine: 3
            )
        )
    }

    func testMismatchedValueKeepsNewlineCaretCorrection() {
        XCTAssertTrue(
            PasteAXInspector.shouldTreatNewlineRangeAtCaret(
                "\n",
                rangeText: "ab",
                value: "xy\ncd",
                caretLocation: 2,
                insertionLine: 3,
                caretIndexLine: 3
            )
        )
    }

    func testNewlineAtEndOfPreviousLineDoesNotOverridePreviousCharacter() {
        XCTAssertFalse(
            PasteAXInspector.shouldTreatNewlineRangeAtCaret(
                "\n",
                insertionLine: 7,
                caretIndexLine: 8
            )
        )
    }

    func testTerminalNewlineUsesElectronCaretCoordinateWithoutLineBreaks() {
        XCTAssertTrue(
            PasteAXInspector.shouldTreatTrailingValueNewlineAsPrecedingCaret(
                rangeText: "abc😀x",
                value: "abc\n😀x\n",
                caretLocation: 6
            )
        )
    }

    func testTrailingWhitespaceRetainsNewlineBoundaryAcrossIndentation() {
        XCTAssertTrue(PasteAXInspector.isAfterNewlineInTrailingWhitespace("first line\n  "))
        XCTAssertFalse(PasteAXInspector.isAfterNewlineInTrailingWhitespace("first line  "))
    }

    func testListMultilineOverridePolicyMatchesPreFixBehavior() {
        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.apple.MobileSMS"
            ),
            equals: .multiline
        )

        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.microsoft.VSCode"
            ),
            equals: .singleLineInline
        )
        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.openai.codex"
            ),
            equals: .singleLineInline
        )
        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.google.antigravity"
            ),
            equals: .singleLineInline
        )
        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.exafunction.windsurf"
            ),
            equals: .singleLineInline
        )
    }

    func testElectronFrameworkDetectionDoesNotDependOnBundleIDAllowlist() {
        XCTAssertTrue(
            PasteService.containsElectronFramework(
                frameworkNames: ["App.framework", "Electron Framework.framework", "Squirrel.framework"]
            )
        )

        XCTAssertFalse(
            PasteService.containsElectronFramework(
                frameworkNames: ["App.framework", "Sparkle.framework", "WebKit.framework"]
            )
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
